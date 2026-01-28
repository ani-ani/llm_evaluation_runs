module bolt_pack_finder #(
    parameter MAX_COMPANIES = 4,
    parameter MAX_PACKS = 4,
    parameter MAX_SUM = 1024,
    parameter DATA_WIDTH = 8,
    parameter TIMEOUT_CYCLES = 5000
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] B,
    input wire [3:0] k,
    input wire [DATA_WIDTH-1:0] pack_sizes [0:MAX_COMPANIES*MAX_PACKS-1],
    input wire [3:0] num_packs [0:MAX_COMPANIES-1],
    output reg [DATA_WIDTH-1:0] result,
    output reg done,
    output reg impossible
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT_REAL = 4'd1;
    localparam [3:0] SETUP_DP = 4'd2;
    localparam [3:0] DP_INNER_LOOP = 4'd3;
    localparam [3:0] DP_UPDATE = 4'd4;
    localparam [3:0] FIND_MIN_SUM = 4'd5;
    localparam [3:0] STORE_RESULT = 4'd6;
    localparam [3:0] NEXT_PACK = 4'd7;
    localparam [3:0] NEXT_COMPANY = 4'd8;
    localparam [3:0] FIND_BEST = 4'd9;
    localparam [3:0] FINISHED = 4'd10;
    
    reg [3:0] state;
    reg [3:0] company_idx;
    reg [3:0] pack_idx;
    reg [DATA_WIDTH-1:0] sum_idx;
    reg [15:0] timeout;
    
    // DP array: dp[s] = minimal real sum to achieve advertised sum s
    reg [DATA_WIDTH-1:0] dp [0:MAX_SUM-1];
    
    // Real amounts storage
    reg [DATA_WIDTH-1:0] real_amounts [0:MAX_COMPANIES*MAX_PACKS-1];
    
    // Previous company's packs for DP
    reg [DATA_WIDTH-1:0] prev_adv [0:MAX_PACKS-1];
    reg [DATA_WIDTH-1:0] prev_real [0:MAX_PACKS-1];
    reg [3:0] prev_num_packs;
    reg [3:0] prev_pack_idx;
    
    // Current computation
    reg [DATA_WIDTH-1:0] current_real;
    reg [DATA_WIDTH-1:0] min_sum;
    
    // Result tracking
    reg [DATA_WIDTH-1:0] best_pack;
    reg best_found;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            company_idx <= 4'd0;
            pack_idx <= 4'd0;
            sum_idx <= 8'd0;
            timeout <= 16'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            result <= 8'd0;
            best_pack <= 8'hFF;
            best_found <= 1'b0;
            
            // Initialize DP array
            for (i = 0; i < MAX_SUM; i = i + 1) begin
                dp[i] <= 8'hFF;
            end
            
            // Initialize real_amounts
            for (i = 0; i < MAX_COMPANIES*MAX_PACKS; i = i + 1) begin
                real_amounts[i] <= 8'd0;
            end
            
            // Initialize previous pack arrays
            for (i = 0; i < MAX_PACKS; i = i + 1) begin
                prev_adv[i] <= 8'd0;
                prev_real[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= INIT_REAL;
                        company_idx <= 4'd0;
                        pack_idx <= 4'd0;
                        best_found <= 1'b0;
                        best_pack <= 8'hFF;
                        impossible <= 1'b0;
                        done <= 1'b0;
                        timeout <= 16'd0;
                    end
                end
                
                INIT_REAL: begin
                    if (pack_idx < num_packs[company_idx]) begin
                        real_amounts[pack_idx] <= pack_sizes[pack_idx];
                        pack_idx <= pack_idx + 4'd1;
                    end else begin
                        pack_idx <= 4'd0;
                        company_idx <= company_idx + 4'd1;
                        state <= (k > 4'd1) ? SETUP_DP : FIND_BEST;
                    end
                end
                
                SETUP_DP: begin
                    if (pack_idx < num_packs[company_idx-4'd1]) begin
                        prev_adv[pack_idx] <= pack_sizes[(company_idx-4'd1)*MAX_PACKS+pack_idx];
                        prev_real[pack_idx] <= real_amounts[(company_idx-4'd1)*MAX_PACKS+pack_idx];
                        pack_idx <= pack_idx + 4'd1;
                    end else begin
                        prev_num_packs <= num_packs[company_idx-4'd1];
                        pack_idx <= 4'd0;
                        prev_pack_idx <= 4'd0;
                        
                        // Initialize DP
                        for (i = 1; i < MAX_SUM; i = i + 1) dp[i] <= 8'hFF;
                        dp[0] <= 8'd0;
                        state <= DP_INNER_LOOP;
                    end
                end
                
                DP_INNER_LOOP: begin
                    if (prev_pack_idx < prev_num_packs) begin
                        sum_idx <= prev_adv[prev_pack_idx];
                        state <= DP_UPDATE;
                    end else begin
                        prev_pack_idx <= 4'd0;
                        sum_idx <= 8'd0;
                        state <= FIND_MIN_SUM;
                        current_real <= 8'hFF;
                    end
                end
                
                DP_UPDATE: begin
                    if (sum_idx < MAX_SUM) begin
                        if (dp[sum_idx - prev_adv[prev_pack_idx]] != 8'hFF) begin
                            if ((dp[sum_idx - prev_adv[prev_pack_idx]] + prev_real[prev_pack_idx]) < dp[sum_idx]) begin
                                dp[sum_idx] <= dp[sum_idx - prev_adv[prev_pack_idx]] + prev_real[prev_pack_idx];
                            end
                        end
                        sum_idx <= sum_idx + 8'd1;
                    end else begin
                        prev_pack_idx <= prev_pack_idx + 4'd1;
                        state <= DP_INNER_LOOP;
                    end
                end
                
                FIND_MIN_SUM: begin
                    if (sum_idx < MAX_SUM) begin
                        if (sum_idx >= pack_sizes[company_idx*MAX_PACKS + pack_idx] && dp[sum_idx] != 8'hFF) begin
                            min_sum <= sum_idx;
                            current_real <= dp[sum_idx];
                            state <= STORE_RESULT;
                        end else begin
                            sum_idx <= sum_idx + 8'd1;
                        end
                    end else begin
                        state <= STORE_RESULT;
                        current_real <= 8'hFF;
                    end
                end
                
                STORE_RESULT: begin
                    real_amounts[company_idx*MAX_PACKS + pack_idx] <= current_real;
                    state <= NEXT_PACK;
                end
                
                NEXT_PACK: begin
                    pack_idx <= pack_idx + 4'd1;
                    if (pack_idx < (num_packs[company_idx] - 4'd1)) begin
                        state <= SETUP_DP;
                    end else begin
                        pack_idx <= 4'd0;
                        company_idx <= company_idx + 4'd1;
                        state <= (company_idx < (k - 4'd1)) ? SETUP_DP : FIND_BEST;
                    end
                end
                
                FIND_BEST: begin
                    if (company_idx < k) begin
                        if (pack_idx < num_packs[company_idx]) begin
                            if (real_amounts[company_idx*MAX_PACKS + pack_idx] >= B) begin
                                if (pack_sizes[company_idx*MAX_PACKS + pack_idx] < best_pack) begin
                                    best_pack <= pack_sizes[company_idx*MAX_PACKS + pack_idx];
                                    best_found <= 1'b1;
                                end
                            end
                            pack_idx <= pack_idx + 4'd1;
                        end else begin
                            pack_idx <= 4'd0;
                            company_idx <= company_idx + 4'd1;
                        end
                    end else begin
                        if (best_found) begin
                            result <= best_pack;
                            impossible <= 1'b0;
                        end else begin
                            result <= 8'd0;
                            impossible <= 1'b1;
                        end
                        done <= 1'b1;
                        state <= FINISHED;
                    end
                end
                
                FINISHED: begin
                    if (!start) begin
                        done <= 1'b0;
                        impossible <= 1'b0;
                        state <= IDLE;
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Timeout logic
            if (state != IDLE && state != FINISHED) begin
                if (timeout >= TIMEOUT_CYCLES) begin
                    impossible <= 1'b1;
                    done <= 1'b1;
                    state <= FINISHED;
                end else begin
                    timeout <= timeout + 16'd1;
                end
            end else begin
                timeout <= 16'd0;
            end
        end
    end
endmodule