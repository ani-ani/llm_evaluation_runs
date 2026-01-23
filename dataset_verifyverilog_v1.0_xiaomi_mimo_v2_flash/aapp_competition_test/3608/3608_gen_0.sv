module task_selection #(
    parameter N = 8,
    parameter DATA_WIDTH = 32,
    parameter MOD = 1000000007
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Input arrays: exact tasks A[0:N-1], flexible tasks B[0:N-2]
    input wire [DATA_WIDTH-1:0] A [0:N-1],
    input wire [DATA_WIDTH-1:0] B [0:N-2],
    
    output reg [DATA_WIDTH-1:0] result,
    output reg done
);
    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state;
    reg [DATA_WIDTH-1:0] f_reg;
    reg [DATA_WIDTH-1:0] g_reg;
    reg [31:0] counter;
    reg [31:0] max_counter;
    reg computation_started;
    
    // Intermediate signals for arithmetic
    wire [DATA_WIDTH-1:0] a_val;
    wire [DATA_WIDTH-1:0] b_val;
    wire [DATA_WIDTH-1:0] b_prev_val;
    wire [DATA_WIDTH*2-1:0] mult_temp1;
    wire [DATA_WIDTH*2-1:0] mult_temp2;
    wire [DATA_WIDTH*2-1:0] mult_temp3;
    wire [DATA_WIDTH-1:0] mult_result1;
    wire [DATA_WIDTH-1:0] mult_result2;
    wire [DATA_WIDTH-1:0] mult_result3;
    wire [DATA_WIDTH-1:0] sum_temp;
    wire [DATA_WIDTH-1:0] diff_temp;
    wire [DATA_WIDTH-1:0] mod_result1;
    wire [DATA_WIDTH-1:0] mod_result2;
    wire [DATA_WIDTH-1:0] mod_result3;
    wire [DATA_WIDTH-1:0] mod_result4;
    
    // Array indexing (avoiding unpacked array issues)
    assign a_val = (counter < N) ? A[counter] : {DATA_WIDTH{1'b0}};
    assign b_val = (counter < N-1) ? B[counter] : {DATA_WIDTH{1'b0}};
    assign b_prev_val = (counter > 0 && counter-1 < N-1) ? B[counter-1] : {DATA_WIDTH{1'b0}};
    
    // Multipliers (64-bit for 32x32)
    assign mult_temp1 = f_reg * a_val;
    assign mult_result1 = mult_temp1[47:16] % MOD;  // Q16.16 style, then mod
    
    assign mult_temp2 = f_reg * b_val;
    assign mult_result2 = mult_temp2[47:16] % MOD;
    
    assign mult_temp3 = f_reg * b_prev_val;
    assign mult_result3 = mult_temp3[47:16] % MOD;
    
    // Additions/subtractions
    assign sum_temp = (a_val + b_prev_val) % MOD;
    
    // Combinational logic for f calculation
    wire [DATA_WIDTH-1:0] f_next_temp;
    wire [DATA_WIDTH-1:0] f_next;
    assign f_next_temp = (mult_result1 + mult_result2 + MOD - g_reg) % MOD;
    assign f_next = (f_next_temp + g_reg) % MOD;  // Corrected: f = f*(a+b_prev) + f*b_curr - g
    
    // Combinational logic for g calculation
    wire [DATA_WIDTH-1:0] g_next;
    assign g_next = mult_result2;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            f_reg <= {DATA_WIDTH{1'b0}};
            g_reg <= {DATA_WIDTH{1'b0}};
            counter <= 32'd0;
            max_counter <= 32'd0;
            done <= 1'b0;
            result <= {DATA_WIDTH{1'b0}};
            computation_started <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    computation_started <= 1'b0;
                    counter <= 32'd0;
                    
                    if (start) begin
                        if (N == 1) begin
                            result <= A[0];
                            done <= 1'b1;
                            state <= DONE_STATE;
                        end else begin
                            f_reg <= (A[0] + B[0]) % MOD;
                            g_reg <= B[0] % MOD;
                            max_counter <= N - 1;
                            counter <= 32'd1;
                            computation_started <= 1'b1;
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    // Update g based on current b_val
                    if (counter < N) begin
                        g_reg <= g_next;
                    end else begin
                        g_reg <= {DATA_WIDTH{1'b0}};
                    end
                    
                    // Update f based on current values
                    f_reg <= f_next;
                    
                    // Increment counter
                    counter <= counter + 32'd1;
                    
                    // Check if computation is complete
                    if (counter >= max_counter) begin
                        state <= DONE_STATE;
                        result <= f_reg;
                        done <= 1'b1;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    f_reg <= {DATA_WIDTH{1'b0}};
                    g_reg <= {DATA_WIDTH{1'b0}};
                    counter <= 32'd0;
                    done <= 1'b0;
                    result <= {DATA_WIDTH{1'b0}};
                end
            endcase
        end
    end
endmodule