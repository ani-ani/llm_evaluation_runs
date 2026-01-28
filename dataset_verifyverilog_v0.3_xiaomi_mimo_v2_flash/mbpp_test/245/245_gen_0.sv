module bitonic_max_sum (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    output reg [15:0] result,
    output reg done
);

    // State machine states
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] LOAD        = 3'd1;
    localparam [2:0] CALC_MSIBS  = 3'd2;
    localparam [2:0] CALC_MSDBS  = 3'd3;
    localparam [2:0] FIND_MAX    = 3'd4;
    localparam [2:0] DONE_STATE  = 3'd5;
    
    // Internal memory for DP arrays (packed for Icarus Verilog compatibility)
    reg [7:0]  arr_reg [0:7];
    reg [15:0] msibs_reg [0:7];
    reg [15:0] msdbs_reg [0:7];
    
    // Registers for state machine
    reg [2:0]  state;
    reg [2:0]  i, j;
    reg [15:0] current_max;
    reg [15:0] temp_sum;
    reg        calc_complete;
    
    // Cycle counter to prevent infinite loops
    reg [15:0] cycle_counter;
    localparam [15:0] MAX_CYCLES = 16'd1000;
    
    // Next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            i <= 3'd0;
            j <= 3'd0;
            current_max <= 16'd0;
            temp_sum <= 16'd0;
            calc_complete <= 1'b0;
            cycle_counter <= 16'd0;
            // Initialize arrays
            arr_reg[0] <= 8'd0; arr_reg[1] <= 8'd0; arr_reg[2] <= 8'd0; arr_reg[3] <= 8'd0;
            arr_reg[4] <= 8'd0; arr_reg[5] <= 8'd0; arr_reg[6] <= 8'd0; arr_reg[7] <= 8'd0;
            msibs_reg[0] <= 16'd0; msibs_reg[1] <= 16'd0; msibs_reg[2] <= 16'd0; msibs_reg[3] <= 16'd0;
            msibs_reg[4] <= 16'd0; msibs_reg[5] <= 16'd0; msibs_reg[6] <= 16'd0; msibs_reg[7] <= 16'd0;
            msdbs_reg[0] <= 16'd0; msdbs_reg[1] <= 16'd0; msdbs_reg[2] <= 16'd0; msdbs_reg[3] <= 16'd0;
            msdbs_reg[4] <= 16'd0; msdbs_reg[5] <= 16'd0; msdbs_reg[6] <= 16'd0; msdbs_reg[7] <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 16'd0;
                    if (start) begin
                        state <= LOAD;
                        i <= 3'd0;
                    end
                end
                
                LOAD: begin
                    // Load input array into internal memory
                    case (i)
                        3'd0: arr_reg[0] <= arr_0;
                        3'd1: arr_reg[1] <= arr_1;
                        3'd2: arr_reg[2] <= arr_2;
                        3'd3: arr_reg[3] <= arr_3;
                        3'd4: arr_reg[4] <= arr_4;
                        3'd5: arr_reg[5] <= arr_5;
                        3'd6: arr_reg[6] <= arr_6;
                        3'd7: arr_reg[7] <= arr_7;
                        default: begin
                            arr_reg[0] <= 8'd0;
                            arr_reg[1] <= 8'd0;
                            arr_reg[2] <= 8'd0;
                            arr_reg[3] <= 8'd0;
                            arr_reg[4] <= 8'd0;
                            arr_reg[5] <= 8'd0;
                            arr_reg[6] <= 8'd0;
                            arr_reg[7] <= 8'd0;
                        end
                    endcase
                    
                    if (i < 7) begin
                        i <= i + 3'd1;
                    end else begin
                        i <= 3'd0;
                        j <= 3'd0;
                        // Initialize MSIBS with array values
                        msibs_reg[0] <= {8'd0, arr_reg[0]};
                        msibs_reg[1] <= {8'd0, arr_reg[1]};
                        msibs_reg[2] <= {8'd0, arr_reg[2]};
                        msibs_reg[3] <= {8'd0, arr_reg[3]};
                        msibs_reg[4] <= {8'd0, arr_reg[4]};
                        msibs_reg[5] <= {8'd0, arr_reg[5]};
                        msibs_reg[6] <= {8'd0, arr_reg[6]};
                        msibs_reg[7] <= {8'd0, arr_reg[7]};
                        state <= CALC_MSIBS;
                    end
                end
                
                CALC_MSIBS: begin
                    cycle_counter <= cycle_counter + 16'd1;
                    
                    // DP calculation for Maximum Sum Increasing Subsequence
                    if (i < 8) begin
                        if (j < i) begin
                            if (arr_reg[i] > arr_reg[j]) begin
                                if (msibs_reg[i] < (msibs_reg[j] + {8'd0, arr_reg[i]})) begin
                                    msibs_reg[i] <= msibs_reg[j] + {8'd0, arr_reg[i]};
                                end
                            end
                            j <= j + 3'd1;
                        end else begin
                            // Done with this i
                            if (i < 7) begin
                                i <= i + 3'd1;
                                j <= 3'd0;
                            end else begin
                                // Initialize MSDBS with array values
                                msdbs_reg[7] <= {8'd0, arr_reg[7]};
                                msdbs_reg[6] <= {8'd0, arr_reg[6]};
                                msdbs_reg[5] <= {8'd0, arr_reg[5]};
                                msdbs_reg[4] <= {8'd0, arr_reg[4]};
                                msdbs_reg[3] <= {8'd0, arr_reg[3]};
                                msdbs_reg[2] <= {8'd0, arr_reg[2]};
                                msdbs_reg[1] <= {8'd0, arr_reg[1]};
                                msdbs_reg[0] <= {8'd0, arr_reg[0]};
                                i <= 3'd0;
                                j <= 3'd0;
                                state <= CALC_MSDBS;
                            end
                        end
                    end
                end
                
                CALC_MSDBS: begin
                    cycle_counter <= cycle_counter + 16'd1;
                    
                    // DP calculation for Maximum Sum Decreasing Subsequence (reverse)
                    if (i < 8) begin
                        if (j < i) begin
                            if (arr_reg[7-i] > arr_reg[7-j]) begin
                                if (msdbs_reg[7-i] < (msdbs_reg[7-j] + {8'd0, arr_reg[7-i]})) begin
                                    msdbs_reg[7-i] <= msdbs_reg[7-j] + {8'd0, arr_reg[7-i]};
                                end
                            end
                            j <= j + 3'd1;
                        end else begin
                            // Done with this i
                            if (i < 7) begin
                                i <= i + 3'd1;
                                j <= 3'd0;
                            end else begin
                                // Ready to find maximum bitonic sum
                                i <= 3'd0;
                                current_max <= 16'd0;
                                calc_complete <= 1'b0;
                                state <= FIND_MAX;
                            end
                        end
                    end
                end
                
                FIND_MAX: begin
                    cycle_counter <= cycle_counter + 16'd1;
                    
                    if (!calc_complete) begin
                        // Find maximum bitonic sum: MSIBS[i] + MSDBS[i] - arr[i]
                        temp_sum <= msibs_reg[i] + msdbs_reg[i] - {8'd0, arr_reg[i]};
                        calc_complete <= 1'b1;
                    end else begin
                        // Compare with current maximum
                        if (temp_sum > current_max) begin
                            current_max <= temp_sum;
                        end
                        
                        if (i < 7) begin
                            i <= i + 3'd1;
                            calc_complete <= 1'b0;
                        end else begin
                            // Final result is ready
                            result <= current_max;
                            state <= DONE_STATE;
                        end
                    end
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