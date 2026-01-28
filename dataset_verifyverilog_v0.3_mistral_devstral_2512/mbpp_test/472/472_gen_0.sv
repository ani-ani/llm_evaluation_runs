module check_consecutive(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    output reg result,
    output reg done
);

    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CAPTURE   = 3'd1;
    localparam [2:0] PROCESS   = 3'd2;
    localparam [2:0] VALIDATE  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state;
    reg [7:0] captured_arr [0:7];
    reg [7:0] min_val;
    reg [7:0] max_val;
    reg [7:0] current_min;
    reg [7:0] current_max;
    reg [7:0] index;
    reg [7:0] temp_val;
    reg [7:0] check_val;
    reg [7:0] duplicate_check;
    reg [7:0] i;
    reg [7:0] j;
    reg found_duplicate;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            index <= 8'd0;
            current_min <= 8'd255;
            current_max <= 8'd0;
            min_val <= 8'd0;
            max_val <= 8'd0;
            temp_val <= 8'd0;
            check_val <= 8'd0;
            duplicate_check <= 8'd0;
            found_duplicate <= 1'b0;
            cycle_count <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                captured_arr[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CAPTURE;
                    end
                end

                CAPTURE: begin
                    for (i = 0; i < 8; i = i + 1) begin
                        captured_arr[i] <= arr[i];
                    end
                    state <= PROCESS;
                    index <= 8'd0;
                    current_min <= 8'd255;
                    current_max <= 8'd0;
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= VALIDATE;
                    end else begin
                        if (index < 8'd8) begin
                            temp_val <= captured_arr[index];
                            if (temp_val < current_min) begin
                                current_min <= temp_val;
                            end
                            if (temp_val > current_max) begin
                                current_max <= temp_val;
                            end
                            index <= index + 8'd1;
                        end else begin
                            min_val <= current_min;
                            max_val <= current_max;
                            index <= 8'd0;
                            found_duplicate <= 1'b0;
                            state <= VALIDATE;
                        end
                    end
                end

                VALIDATE: begin
                    if (max_val - min_val + 8'd1 == 8'd8) begin
                        found_duplicate <= 1'b0;
                        for (i = 0; i < 8; i = i + 1) begin
                            check_val <= captured_arr[i];
                            for (j = i + 8'd1; j < 8; j = j + 1) begin
                                if (captured_arr[j] == check_val) begin
                                    found_duplicate <= 1'b1;
                                end
                            end
                        end
                        if (!found_duplicate) begin
                            result <= 1'b1;
                        end else begin
                            result <= 1'b0;
                        end
                    end else begin
                        result <= 1'b0;
                    end
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule