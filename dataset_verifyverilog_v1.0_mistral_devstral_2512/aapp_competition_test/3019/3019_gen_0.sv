module max_revenue(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [9:0] S_0,
    input wire [9:0] S_1,
    input wire [9:0] S_2,
    input wire [9:0] S_3,
    input wire [9:0] S_4,
    input wire [9:0] S_5,
    input wire [9:0] S_6,
    input wire [9:0] S_7,
    input wire [9:0] S_8,
    input wire [9:0] S_9,
    input wire [9:0] S_10,
    input wire [9:0] S_11,
    input wire [9:0] S_12,
    input wire [9:0] S_13,
    output reg [6:0] result,
    output reg done
);

    // States
    localparam [4:0] IDLE = 5'd0;
    localparam [4:0] INIT_START = 5'd1;
    localparam [4:0] INIT_SUM = 5'd2;
    localparam [4:0] INIT_OMEGA = 5'd3;
    localparam [4:0] INIT_NEXT = 5'd4;
    localparam [4:0] DP_START = 5'd5;
    localparam [4:0] DP_OUTER = 5'd6;
    localparam [4:0] DP_INNER = 5'd7;
    localparam [4:0] DP_NEXT = 5'd8;
    localparam [4:0] DP_STORE = 5'd9;
    localparam [4:0] DONE_STATE = 5'd10;

    // Memories
    reg [13:0] subset_sum [0:16383];
    reg [2:0] subset_omega [0:16383];
    reg [6:0] dp [0:16383];

    // State and counters
    reg [4:0] state;
    reg [13:0] mask;
    reg [13:0] submask;
    reg [13:0] max_mask;
    reg [6:0] max_val;
    reg [6:0] candidate;
    reg [6:0] current_omega;
    reg [6:0] prime_index;
    reg [6:0] prime_count;
    reg [13:0] current_sum;
    reg [13:0] temp_sum;
    reg [9:0] current_S;
    reg [13:0] i;

    // Prime list (primes up to 118)
    localparam [9:0] primes [0:30] = '{10'd2, 10'd3, 10'd5, 10'd7, 10'd11, 10'd13, 10'd17, 10'd19, 10'd23, 10'd29, 10'd31, 10'd37, 10'd41, 10'd43, 10'd47, 10'd53, 10'd59, 10'd61, 10'd67, 10'd71, 10'd73, 10'd79, 10'd83, 10'd89, 10'd97, 10'd101, 10'd103, 10'd107, 10'd109, 10'd113};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            mask <= 14'd0;
            submask <= 14'd0;
            max_mask <= 14'd0;
            max_val <= 7'd0;
            candidate <= 7'd0;
            current_omega <= 3'd0;
            prime_index <= 7'd0;
            prime_count <= 3'd0;
            current_sum <= 14'd0;
            temp_sum <= 14'd0;
            current_S <= 10'd0;
            i <= 14'd0;
            result <= 7'd0;
            done <= 1'b0;
            
            // Initialize memories
            for (i = 0; i < 14'd16384; i = i + 1) begin
                subset_sum[i] <= 14'd0;
                subset_omega[i] <= 3'd0;
                dp[i] <= 7'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT_START;
                    end
                end
                
                INIT_START: begin
                    max_mask <= (1 << N) - 1;
                    mask <= 14'd1;
                    state <= INIT_SUM;
                end
                
                INIT_SUM: begin
                    // Compute subset_sum[mask]
                    if (mask[0]) begin
                        current_S <= S_0;
                    end else if (mask[1]) begin
                        current_S <= S_1;
                    end else if (mask[2]) begin
                        current_S <= S_2;
                    end else if (mask[3]) begin
                        current_S <= S_3;
                    end else if (mask[4]) begin
                        current_S <= S_4;
                    end else if (mask[5]) begin
                        current_S <= S_5;
                    end else if (mask[6]) begin
                        current_S <= S_6;
                    end else if (mask[7]) begin
                        current_S <= S_7;
                    end else if (mask[8]) begin
                        current_S <= S_8;
                    end else if (mask[9]) begin
                        current_S <= S_9;
                    end else if (mask[10]) begin
                        current_S <= S_10;
                    end else if (mask[11]) begin
                        current_S <= S_11;
                    end else if (mask[12]) begin
                        current_S <= S_12;
                    end else if (mask[13]) begin
                        current_S <= S_13;
                    end
                    
                    temp_sum <= subset_sum[mask >> 1];
                    current_sum <= temp_sum + current_S;
                    subset_sum[mask] <= current_sum;
                    state <= INIT_OMEGA;
                end
                
                INIT_OMEGA: begin
                    // Compute omega for current_sum
                    if (prime_index == 7'd0) begin
                        prime_count <= 3'd0;
                        current_omega <= 3'd0;
                    end
                    
                    if (prime_index < 7'd30) begin
                        if (current_sum % primes[prime_index] == 0) begin
                            current_omega <= current_omega + 1'b1;
                        end
                        prime_index <= prime_index + 1'b1;
                    end else begin
                        subset_omega[mask] <= current_omega;
                        prime_index <= 7'd0;
                        state <= INIT_NEXT;
                    end
                end
                
                INIT_NEXT: begin
                    if (mask == max_mask) begin
                        state <= DP_START;
                    end else begin
                        mask <= mask + 1'b1;
                        state <= INIT_SUM;
                    end
                end
                
                DP_START: begin
                    dp[0] <= 7'd0;
                    mask <= 14'd1;
                    state <= DP_OUTER;
                end
                
                DP_OUTER: begin
                    max_val <= 7'd0;
                    submask <= mask;
                    state <= DP_INNER;
                end
                
                DP_INNER: begin
                    if (submask != 0) begin
                        candidate <= dp[mask ^ submask] + subset_omega[submask];
                        if (candidate > max_val) begin
                            max_val <= candidate;
                        end
                        submask <= (submask - 1) & mask;
                    end else begin
                        state <= DP_STORE;
                    end
                end
                
                DP_STORE: begin
                    dp[mask] <= max_val;
                    if (mask == max_mask) begin
                        state <= DONE_STATE;
                    end else begin
                        mask <= mask + 1'b1;
                        state <= DP_OUTER;
                    end
                end
                
                DONE_STATE: begin
                    result <= dp[max_mask];
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule