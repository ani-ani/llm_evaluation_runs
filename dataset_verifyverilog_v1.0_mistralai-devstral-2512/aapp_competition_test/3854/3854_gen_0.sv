module subset_subsets(
    input clk,
    input rst_n,
    input start,
    input [3:0] n_in,
    input [8:0] k_in,
    input [8:0] coin_i,
    output reg done,
    output reg [4:0] result_count,
    output reg [8:0] result_x [0:31]
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOAD    = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] OUTPUT  = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] coin_index;
    reg [8:0] current_k;
    reg [8:0] current_coin;
    reg [8:0] scan_index;
    reg [4:0] count;
    reg [8:0] dp_reg [0:511];
    reg [8:0] coins [0:15];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            coin_index <= 4'd0;
            current_k <= 9'd0;
            current_coin <= 9'd0;
            scan_index <= 9'd0;
            count <= 5'd0;
            done <= 1'b0;
            result_count <= 5'd0;
            
            // Initialize result_x array
            integer i;
            for (i = 0; i < 32; i = i + 1) begin
                result_x[i] <= 9'd0;
            end
            
            // Initialize dp_reg
            for (i = 0; i < 512; i = i + 1) begin
                dp_reg[i] <= 9'd0;
            end
            dp_reg[0] <= 9'd1;  // dp[0] = 1 (bit 0 set)
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= LOAD;
                        coin_index <= 4'd0;
                        current_k <= k_in;
                    end
                end
                
                LOAD: begin
                    if (coin_index < n_in) begin
                        coins[coin_index] <= coin_i;
                        coin_index <= coin_index + 4'd1;
                    end else begin
                        next_state <= COMPUTE;
                        coin_index <= 4'd0;
                    end
                end
                
                COMPUTE: begin
                    if (coin_index < n_in) begin
                        current_coin <= coins[coin_index];
                        
                        // Update dp_reg for current coin
                        integer s;
                        for (s = current_k; s >= current_coin; s = s - 1) begin
                            reg [8:0] new_bits;
                            reg [8:0] shifted_bits;
                            
                            new_bits = dp_reg[s - current_coin];
                            shifted_bits = dp_reg[s - current_coin] << current_coin;
                            
                            dp_reg[s] = dp_reg[s] | new_bits | shifted_bits;
                        end
                        
                        coin_index <= coin_index + 4'd1;
                    end else begin
                        next_state <= OUTPUT;
                        scan_index <= 9'd0;
                        count <= 5'd0;
                    end
                end
                
                OUTPUT: begin
                    if (scan_index <= current_k) begin
                        if (dp_reg[current_k][scan_index]) begin
                            result_x[count] <= scan_index;
                            count <= count + 5'd1;
                        end
                        scan_index <= scan_index + 9'd1;
                    end else begin
                        result_count <= count;
                        done <= 1'b1;
                        next_state <= IDLE;
                    end
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule