module triple_sum_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] arr_0,
    input wire signed [15:0] arr_1,
    input wire signed [15:0] arr_2,
    input wire signed [15:0] arr_3,
    input wire signed [15:0] arr_4,
    input wire signed [15:0] arr_5,
    input wire signed [15:0] arr_6,
    input wire signed [15:0] arr_7,
    input wire signed [15:0] arr_8,
    input wire signed [15:0] arr_9,
    input wire signed [15:0] arr_10,
    input wire signed [15:0] arr_11,
    input wire signed [15:0] arr_12,
    input wire signed [15:0] arr_13,
    input wire signed [15:0] arr_14,
    input wire signed [15:0] arr_15,
    output reg [15:0] result,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] i_counter;      // 0-15
    reg [3:0] j_counter;      // 0-15
    reg [3:0] k_counter;      // 0-15
    reg [15:0] result_reg;
    reg [11:0] iteration_count; // 0-4095

    // Combinational signals
    wire signed [15:0] arr_reg [0:15];
    wire distinct;
    wire signed [15:0] sum;
    wire match;

    // Map input ports to array for indexed access
    assign arr_reg[0] = arr_0;
    assign arr_reg[1] = arr_1;
    assign arr_reg[2] = arr_2;
    assign arr_reg[3] = arr_3;
    assign arr_reg[4] = arr_4;
    assign arr_reg[5] = arr_5;
    assign arr_reg[6] = arr_6;
    assign arr_reg[7] = arr_7;
    assign arr_reg[8] = arr_8;
    assign arr_reg[9] = arr_9;
    assign arr_reg[10] = arr_10;
    assign arr_reg[11] = arr_11;
    assign arr_reg[12] = arr_12;
    assign arr_reg[13] = arr_13;
    assign arr_reg[14] = arr_14;
    assign arr_reg[15] = arr_15;

    // Check if indices are pairwise distinct
    assign distinct = (i_counter != j_counter) && (i_counter != k_counter) && (j_counter != k_counter);

    // 16-bit signed addition
    assign sum = arr_reg[i_counter] + arr_reg[j_counter];

    // Compare sum with arr[k]
    assign match = (sum == arr_reg[k_counter]) && distinct;

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Synchronous reset
            state <= IDLE;
            result_reg <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            valid <= 1'b0;
            i_counter <= 4'd0;
            j_counter <= 4'd0;
            k_counter <= 4'd0;
            iteration_count <= 12'd0;
        end else begin
            case (state)
                IDLE: begin
                    // Clear outputs
                    done <= 1'b0;
                    valid <= 1'b0;
                    result <= 16'd0;
                    
                    if (start) begin
                        // Initialize counters
                        i_counter <= 4'd0;
                        j_counter <= 4'd0;
                        k_counter <= 4'd0;
                        result_reg <= 16'd0;
                        iteration_count <= 12'd0;
                        state <= PROCESSING;
                    end
                end

                PROCESSING: begin
                    // Increment iteration count
                    iteration_count <= iteration_count + 12'd1;

                    // Check condition and update result
                    if (match) begin
                        result_reg <= result_reg + 16'd1;
                    end

                    // Update k counter
                    if (k_counter < 4'd15) begin
                        k_counter <= k_counter + 4'd1;
                    end else begin
                        // k reached 15, reset k and update j
                        k_counter <= 4'd0;
                        
                        if (j_counter < 4'd15) begin
                            j_counter <= j_counter + 4'd1;
                        end else begin
                            // j reached 15, reset j and update i
                            j_counter <= 4'd0;
                            
                            if (i_counter < 4'd15) begin
                                i_counter <= i_counter + 4'd1;
                            end else begin
                                // i reached 15, all iterations complete
                                state <= DONE_STATE;
                            end
                        end
                    end
                end

                DONE_STATE: begin
                    // Latch result and assert done/valid
                    result <= result_reg;
                    done <= 1'b1;
                    valid <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule