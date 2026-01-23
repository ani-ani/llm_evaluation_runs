module WatchLaterMinClicks (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] video_types [0:15],
    input wire [4:0] length,
    output reg [7:0] result,
    output reg done
);

    // Parameters
    localparam [4:0] MAX_VIDEOS = 5'd16;
    localparam [3:0] MAX_TYPES = 4'd8;
    localparam [2:0] STATE_IDLE = 3'd0;
    localparam [2:0] STATE_COUNT_SEGMENTS = 3'd1;
    localparam [2:0] STATE_FIND_MIN = 3'd2;
    localparam [2:0] STATE_REMOVE_TYPE = 3'd3;
    localparam [2:0] STATE_UPDATE_RESULT = 3'd4;
    localparam [2:0] STATE_DONE = 3'd5;

    // Registers
    reg [2:0] state;
    reg [7:0] current_videos [0:15];
    reg [4:0] remaining_length;
    reg [7:0] segment_counts [0:7];
    reg [7:0] min_segments;
    reg [2:0] selected_type;
    reg [3:0] type_index;
    reg [4:0] video_index;
    reg [7:0] temp_result;
    reg [7:0] last_type;
    reg counting_done;

    // Helper: Map ASCII to type index (0-7)
    function automatic [2:0] char_to_type(input [7:0] c);
        begin
            char_to_type = c[2:0];
        end
    endfunction

    // Helper: Check if two types are same
    function automatic is_same_type(input [7:0] a, input [7:0] b);
        begin
            is_same_type = (a == b);
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            result <= 8'd0;
            done <= 1'b0;
            remaining_length <= 5'd0;
            temp_result <= 8'd0;
            type_index <= 4'd0;
            video_index <= 5'd0;
            min_segments <= 8'hFF;
            selected_type <= 3'd0;
            last_type <= 8'd0;
            counting_done <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    if (start && length > 0) begin
                        // Initialize current_videos from input
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < length)
                                current_videos[i] <= video_types[i];
                            else
                                current_videos[i] <= 8'hFF;
                        end
                        remaining_length <= length;
                        temp_result <= 8'd0;
                        state <= STATE_COUNT_SEGMENTS;
                        type_index <= 4'd0;
                        video_index <= 5'd0;
                        counting_done <= 1'b0;
                    end
                end

                STATE_COUNT_SEGMENTS: begin
                    if (type_index < MAX_TYPES) begin
                        if (!counting_done) begin
                            segment_counts[type_index] <= 8'd0;
                            video_index <= 5'd0;
                            last_type <= 8'hFF;
                            counting_done <= 1'b1;
                        end else if (video_index < remaining_length) begin
                            if (current_videos[video_index] != 8'hFF) begin
                                if (char_to_type(current_videos[video_index]) == type_index[2:0]) begin
                                    if (video_index == 5'd0 ||
                                        last_type == 8'hFF ||
                                        !is_same_type(current_videos[video_index-1], current_videos[video_index])) begin
                                        segment_counts[type_index] <= segment_counts[type_index] + 1;
                                    end
                                    last_type <= current_videos[video_index];
                                end
                            end
                            video_index <= video_index + 1;
                        end else begin
                            counting_done <= 1'b0;
                            type_index <= type_index + 1;
                        end
                    end else begin
                        type_index <= 4'd0;
                        state <= STATE_FIND_MIN;
                        min_segments <= 8'hFF;
                        selected_type <= 3'd0;
                    end
                end

                STATE_FIND_MIN: begin
                    if (type_index < MAX_TYPES) begin
                        if (segment_counts[type_index] > 0 && segment_counts[type_index] < min_segments) begin
                            min_segments <= segment_counts[type_index];
                            selected_type <= type_index[2:0];
                        end
                        type_index <= type_index + 1;
                    end else begin
                        if (min_segments != 8'hFF && remaining_length > 0) begin
                            video_index <= 5'd0;
                            state <= STATE_REMOVE_TYPE;
                        end else begin
                            state <= STATE_DONE;
                        end
                    end
                end

                STATE_REMOVE_TYPE: begin
                    if (video_index < remaining_length) begin
                        if (current_videos[video_index] != 8'hFF &&
                            char_to_type(current_videos[video_index]) == selected_type) begin
                            integer i;
                            for (i = 0; i < 15; i = i + 1) begin
                                if (i >= video_index && i < remaining_length - 1) begin
                                    current_videos[i] <= current_videos[i + 1];
                                end
                            end
                            current_videos[remaining_length - 1] <= 8'hFF;
                            remaining_length <= remaining_length - 1;
                        end else begin
                            video_index <= video_index + 1;
                        end
                    end else begin
                        state <= STATE_UPDATE_RESULT;
                    end
                end

                STATE_UPDATE_RESULT: begin
                    temp_result <= temp_result + min_segments;
                    state <= STATE_COUNT_SEGMENTS;
                    type_index <= 4'd0;
                    video_index <= 5'd0;
                    counting_done <= 1'b0;
                end

                STATE_DONE: begin
                    result <= temp_result;
                    done <= 1'b1;
                    state <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule