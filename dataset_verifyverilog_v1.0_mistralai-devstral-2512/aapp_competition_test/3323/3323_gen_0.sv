module juice_mixer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [13:0] A [0:11],
    input wire [13:0] B [0:11],
    input wire [13:0] C [0:11],
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [11:0] subset_counter;
    reg [3:0] current_max;
    reg [3:0] best_max;
    
    reg [13:0] max_A;
    reg [13:0] max_B;
    reg [13:0] max_C;
    reg [13:0] sum_max;
    
    integer i;
    reg [13:0] temp_A;
    reg [13:0] temp_B;
    reg [13:0] temp_C;
    reg [13:0] temp_sum;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            subset_counter <= 12'd0;
            current_max <= 4'd0;
            best_max <= 4'd0;
            result <= 4'd0;
            done <= 1'b0;
            max_A <= 14'd0;
            max_B <= 14'd0;
            max_C <= 14'd0;
            sum_max <= 14'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        subset_counter <= 12'd0;
                        best_max <= 4'd0;
                    end
                end
                
                COMPUTE: begin
                    // Initialize max values for this subset
                    max_A <= 14'd0;
                    max_B <= 14'd0;
                    max_C <= 14'd0;
                    current_max <= 4'd0;
                    
                    // Check each person in subset
                    for (i = 0; i < 12; i = i + 1) begin
                        if (subset_counter[i]) begin
                            temp_A = A[i];
                            temp_B = B[i];
                            temp_C = C[i];
                            
                            if (temp_A > max_A) max_A <= temp_A;
                            if (temp_B > max_B) max_B <= temp_B;
                            if (temp_C > max_C) max_C <= temp_C;
                            current_max <= current_max + 4'd1;
                        end
                    end
                    
                    // Check if this subset is valid
                    temp_sum = max_A + max_B + max_C;
                    if (temp_sum <= 14'd10000 && current_max > best_max) begin
                        best_max <= current_max;
                    end
                    
                    // Move to next subset
                    subset_counter <= subset_counter + 12'd1;
                    
                    // Check if all subsets processed
                    if (subset_counter == 12'd4095) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= best_max;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule