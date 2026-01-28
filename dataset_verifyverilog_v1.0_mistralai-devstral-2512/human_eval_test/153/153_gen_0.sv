module StrongestExtensionFinder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] class_name,
    input wire [3:0] num_extensions,
    input wire [127:0] ext_name_i,
    input wire [3:0] ext_index,
    output reg [255:0] result_name,
    output reg signed [7:0] result_strength,
    output reg [3:0] result_index,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COUNTING = 2'd1;
    localparam [1:0] COMPARING = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Internal registers for processing
    reg [3:0] current_index;
    reg [3:0] best_index;
    reg signed [7:0] current_strength;
    reg signed [7:0] best_strength;
    reg [127:0] best_extension;

    // Character processing
    reg [7:0] char_count;
    reg [7:0] cap_count;
    reg [7:0] sm_count;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            current_index <= 4'd0;
            best_index <= 4'd0;
            current_strength <= 8'd0;
            best_strength <= 8'd0;
            best_extension <= 128'd0;
            char_count <= 8'd0;
            cap_count <= 8'd0;
            sm_count <= 8'd0;
            result_name <= 256'd0;
            result_strength <= 8'd0;
            result_index <= 4'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= COUNTING;
                        current_index <= 4'd0;
                        best_index <= 4'd0;
                        current_strength <= 8'd0;
                        best_strength <= 8'd0;
                        best_extension <= 128'd0;
                        char_count <= 8'd0;
                        cap_count <= 8'd0;
                        sm_count <= 8'd0;
                    end
                end

                COUNTING: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Process current character
                    if (char_count < 8'd16) begin
                        // Extract current character
                        reg [7:0] current_char;
                        current_char = ext_name_i[(char_count * 8) +: 8];

                        // Check if uppercase
                        if (current_char >= 8'd65 && current_char <= 8'd90) begin
                            cap_count <= cap_count + 8'd1;
                        end
                        // Check if lowercase
                        else if (current_char >= 8'd97 && current_char <= 8'd122) begin
                            sm_count <= sm_count + 8'd1;
                        end

                        char_count <= char_count + 8'd1;
                    end
                    // Done counting characters
                    else begin
                        current_strength <= cap_count - sm_count;
                        next_state <= COMPARING;
                        char_count <= 8'd0;
                        cap_count <= 8'd0;
                        sm_count <= 8'd0;
                    end
                end

                COMPARING: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compare current strength with best
                    if (current_strength > best_strength) begin
                        best_strength <= current_strength;
                        best_index <= ext_index;
                        best_extension <= ext_name_i;
                    end

                    // Move to next extension or finish
                    if (current_index < num_extensions - 4'd1) begin
                        next_state <= COUNTING;
                        current_index <= current_index + 4'd1;
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    // Construct result string: class_name + '.' + best_extension
                    result_name[127:0] <= class_name;
                    result_name[135:128] <= 8'd46; // '.'
                    result_name[255:136] <= best_extension;
                    result_strength <= best_strength;
                    result_index <= best_index;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule