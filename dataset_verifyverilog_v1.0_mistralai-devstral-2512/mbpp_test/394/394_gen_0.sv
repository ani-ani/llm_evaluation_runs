module duplicate_checker(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [7:0] arr_8,
    input [7:0] arr_9,
    input [7:0] arr_10,
    input [7:0] arr_11,
    input [7:0] arr_12,
    input [7:0] arr_13,
    input [7:0] arr_14,
    input [7:0] arr_15,
    input [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECKING = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] outer_idx;
    reg [3:0] inner_idx;
    reg [7:0] current_val;
    reg [7:0] compare_val;
    reg duplicate_found;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Array of input values
    reg [7:0] arr [0:15];

    // Initialize array with input signals
    always @(*) begin
        arr[0] = arr_0;
        arr[1] = arr_1;
        arr[2] = arr_2;
        arr[3] = arr_3;
        arr[4] = arr_4;
        arr[5] = arr_5;
        arr[6] = arr_6;
        arr[7] = arr_7;
        arr[8] = arr_8;
        arr[9] = arr_9;
        arr[10] = arr_10;
        arr[11] = arr_11;
        arr[12] = arr_12;
        arr[13] = arr_13;
        arr[14] = arr_14;
        arr[15] = arr_15;
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            outer_idx <= 4'd0;
            inner_idx <= 4'd0;
            current_val <= 8'd0;
            compare_val <= 8'd0;
            duplicate_found <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state = CHECKING;
                        outer_idx <= 4'd0;
                        inner_idx <= 4'd0;
                        duplicate_found <= 1'b0;
                    end else begin
                        next_state = IDLE;
                    end
                end

                CHECKING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Get current value to check
                    current_val <= arr[outer_idx];
                    
                    // Compare with all previous elements
                    if (!duplicate_found) begin
                        if (inner_idx < outer_idx) begin
                            compare_val <= arr[inner_idx];
                            if (current_val == compare_val) begin
                                duplicate_found <= 1'b1;
                                result <= 1'b0;
                            end
                            inner_idx <= inner_idx + 4'd1;
                        end else begin
                            // Move to next element
                            outer_idx <= outer_idx + 4'd1;
                            inner_idx <= 4'd0;
                            
                            // Check if we've processed all elements
                            if (outer_idx >= len) begin
                                if (!duplicate_found) begin
                                    result <= 1'b1;
                                end
                                next_state = FINISH;
                            end
                        end
                    end else begin
                        next_state = FINISH;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state = FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state = IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 1'b0;
                end
            endcase
        end
    end

endmodule