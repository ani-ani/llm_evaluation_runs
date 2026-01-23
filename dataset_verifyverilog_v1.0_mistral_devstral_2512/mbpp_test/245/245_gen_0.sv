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

    // Fixed array size of 8 elements
    parameter ARRAY_SIZE = 8;
    
    // Internal memory for DP arrays
    reg [7:0] arr_reg [0:7];
    reg [15:0] MSIBS [0:7];  // Maximum sum increasing subsequence
    reg [15:0] MSDBS [0:7];  // Maximum sum decreasing subsequence
    
    // State machine states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] CALC_MSIBS = 3'd2;
    localparam [2:0] CALC_MSDBS = 3'd3;
    localparam [2:0] FIND_MAX = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;
    
    reg [2:0] state;
    reg [2:0] i, j;  // Loop counters
    reg [15:0] current_max;
    reg [15:0] temp_sum;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            i <= 3'd0;
            j <= 3'd0;
            current_max <= 16'd0;
            temp_sum <= 16'd0;
            
            // Initialize arrays
            integer k;
            for (k = 0; k < 8; k = k + 1) begin
                arr_reg[k] <= 8'd0;
                MSIBS[k] <= 16'd0;
                MSDBS[k] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        i <= 3'd0;
                    end
                end
                
                LOAD: begin
                    // Load input array
                    case (i)
                        3'd0: arr_reg[0] <= arr_0;
                        3'd1: arr_reg[1] <= arr_1;
                        3'd2: arr_reg[2] <= arr_2;
                        3'd3: arr_reg[3] <= arr_3;
                        3'd4: arr_reg[4] <= arr_4;
                        3'd5: arr_reg[5] <= arr_5;
                        3'd6: arr_reg[6] <= arr_6;
                        3'd7: arr_reg[7] <= arr_7;
                    endcase
                    
                    if (i < 3'd7) begin
                        i <= i + 3'd1;
                    end else begin
                        i <= 3'd0;
                        j <= 3'd0;
                        state <= CALC_MSIBS;
                    end
                end
                
                CALC_MSIBS: begin
                    // Initialize MSIBS with array values
                    if (i == 3'd0) begin
                        MSIBS[j] <= arr_reg[j];
                        if (j < 3'd7) begin
                            j <= j + 3'd1;
                        end else begin
                            i <= 3'd1;
                            j <= 3'd0;
                        end
                    end else begin
                        // DP calculation for increasing subsequence
                        if (j < i) begin
                            if (arr_reg[i] > arr_reg[j] && MSIBS[i] < MSIBS[j] + arr_reg[i]) begin
                                MSIBS[i] <= MSIBS[j] + arr_reg[i];
                            end
                            j <= j + 3'd1;
                        end else begin
                            j <= 3'd0;
                            if (i < 3'd7) begin
                                i <= i + 3'd1;
                            end else begin
                                i <= 3'd0;
                                j <= 3'd0;
                                state <= CALC_MSDBS;
                            end
                        end
                    end
                end
                
                CALC_MSDBS: begin
                    // Initialize MSDBS with array values (reverse processing)
                    if (i == 3'd0) begin
                        MSDBS[7 - j] <= arr_reg[7 - j];
                        if (j < 3'd7) begin
                            j <= j + 3'd1;
                        end else begin
                            i <= 3'd1;
                            j <= 3'd0;
                        end
                    end else begin
                        // DP calculation for decreasing subsequence (reverse)
                        if (j < i) begin
                            if (arr_reg[7 - i] > arr_reg[7 - j] && MSDBS[7 - i] < MSDBS[7 - j] + arr_reg[7 - i]) begin
                                MSDBS[7 - i] <= MSDBS[7 - j] + arr_reg[7 - i];
                            end
                            j <= j + 3'd1;
                        end else begin
                            j <= 3'd0;
                            if (i < 3'd7) begin
                                i <= i + 3'd1;
                            end else begin
                                i <= 3'd0;
                                current_max <= 16'd0;
                                state <= FIND_MAX;
                            end
                        end
                    end
                end
                
                FIND_MAX: begin
                    // Find maximum bitonic sum: MSIBS[i] + MSDBS[i] - arr[i]
                    temp_sum <= MSIBS[i] + MSDBS[i] - arr_reg[i];
                    
                    if (temp_sum > current_max) begin
                        current_max <= temp_sum;
                    end
                    
                    if (i < 3'd7) begin
                        i <= i + 3'd1;
                    end else begin
                        result <= current_max;
                        state <= DONE_STATE;
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