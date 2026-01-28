module lcm_tree_counter #(
    parameter MAX_NODES = 8,
    parameter DATA_WIDTH = 32,
    parameter RESULT_WIDTH = 32,
    parameter MOD = 32'd1000000007
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    input wire [DATA_WIDTH-1:0] node_vals_0,
    input wire [DATA_WIDTH-1:0] node_vals_1,
    input wire [DATA_WIDTH-1:0] node_vals_2,
    input wire [DATA_WIDTH-1:0] node_vals_3,
    input wire [DATA_WIDTH-1:0] node_vals_4,
    input wire [DATA_WIDTH-1:0] node_vals_5,
    input wire [DATA_WIDTH-1:0] node_vals_6,
    input wire [DATA_WIDTH-1:0] node_vals_7,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

// State declarations
localparam [2:0] IDLE       = 3'd0;
localparam [2:0] INIT       = 3'd1;
localparam [2:0] PROCESS    = 3'd2;
localparam [2:0] FINAL_SUM  = 3'd3;
localparam [2:0] DONE_STATE = 3'd4;
reg [2:0] state;

reg [DATA_WIDTH-1:0] vals [0:7];
reg [31:0] dp [0:255][0:7];
reg [7:0] mask;
reg [2:0] v_idx, a_idx, b_idx;
reg [7:0] rem_mask, submask;
reg gcd_start;
reg [DATA_WIDTH-1:0] gcd_a, gcd_b;
wire gcd_done;
wire [DATA_WIDTH-1:0] gcd_result;

// Control registers
reg [7:0] cycle_counter;
reg [7:0] mask_size;
reg [31:0] temp_mod;
reg [31:0] temp_mult;
reg [63:0] product;
reg [31:0] sum_reg;
reg sub_state;

// GCD module
gcd_module gcd_inst (
    .clk(clk),
    .rst_n(rst_n),
    .start(gcd_start),
    .a(gcd_a),
    .b(gcd_b),
    .result(gcd_result),
    .done(gcd_done)
);

integer i, j; // Loop counters

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 32'd0;
        gcd_start <= 1'b0;
        
        // Initialize DP table
        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                dp[i][j] <= 32'd0;
            end
        end
        
        // Initialize node values
        for (i = 0; i < 8; i = i + 1) begin
            vals[i] <= 32'd0;
        end
        
        mask <= 8'd0;
        v_idx <= 3'd0;
        cycle_counter <= 8'd0;
        temp_mod <= 32'd0;
        sub_state <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_counter <= 8'd0;
                if (start) begin
                    // Store input values
                    vals[0] <= node_vals_0;
                    vals[1] <= node_vals_1;
                    vals[2] <= node_vals_2;
                    vals[3] <= node_vals_3;
                    vals[4] <= node_vals_4;
                    vals[5] <= node_vals_5;
                    vals[6] <= node_vals_6;
                    vals[7] <= node_vals_7;
                    state <= INIT;
                end
            end
            
            INIT: begin
                // Initialize masks with size 1
                for (i = 0; i < 8; i = i + 1) begin
                    if (i[2:0] < n) begin
                        dp[1 << i][i] <= 32'd1;
                    end
                end
                mask_size <= 3'd1;
                state <= PROCESS;
            end
            
            PROCESS: begin
                if (mask_size < n) begin
                    mask_size <= mask_size + 3'd1;
                    
                    // Iterate through all masks
                    for (mask = 1; mask < (1 << n); mask = mask + 1) begin
                        if ($countones(mask) == mask_size) begin
                            // Iterate through all nodes
                            for (v_idx = 0; v_idx < n; v_idx = v_idx + 1) begin
                                if (mask[v_idx]) begin
                                    rem_mask = mask ^ (1 << v_idx);
                                    
                                    // Find two children
                                    for (a_idx = 0; a_idx < n; a_idx = a_idx + 1) begin
                                        for (b_idx = 0; b_idx < n; b_idx = b_idx + 1) begin
                                            if ((rem_mask[a_idx] && rem_mask[b_idx]) && (a_idx != b_idx)) begin
                                                // Calculate GCD of node vals
                                                gcd_a <= vals[a_idx];
                                                gcd_b <= vals[b_idx];
                                                gcd_start <= 1'b1;
                                                
                                                if (gcd_done) begin
                                                    // Calculate LCM = (a * b) / GCD
                                                    product = vals[a_idx] * vals[b_idx];
                                                    temp_mod <= product / gcd_result;
                                                    
                                                    // Check LCM condition
                                                    if (temp_mod % vals[v_idx] == 0) begin
                                                        for (submask = 0; submask < rem_mask; submask = submask + 1) begin
                                                            if ((submask & rem_mask) == submask && submask[a_idx] && submask[b_idx]) begin
                                                                dp[mask][v_idx] <= (dp[mask][v_idx] + 
                                                                    dp[submask | (1 << a_idx)][a_idx] * 
                                                                    dp[rem_mask ^ submask | (1 << b_idx)][b_idx] 
                                                                ) % MOD;
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end else begin
                    state <= FINAL_SUM;
                end
            end
            
            FINAL_SUM: begin
                sum_reg <= 32'd0;
                for (v_idx = 0; v_idx < n; v_idx = v_idx + 1) begin
                    sum_reg <= (sum_reg + dp[(1 << n)-1][v_idx]) % MOD;
                end
                result <= sum_reg;
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

module gcd_module (
    input wire clk,
    input wire rst_n,
    input wire start,
    input [31:0] a,
    input [31:0] b,
    output reg [31:0] result,
    output reg done
);
    reg [2:0] state;
    localparam IDLE = 0;
    localparam CALC = 1;
    localparam FINISH = 2;
    
    reg [31:0] temp_a, temp_b;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        temp_a <= a;
                        temp_b <= b;
                        state <= CALC;
                    end
                end
                
                CALC: begin
                    if (temp_b != 0) begin
                        temp_a <= temp_b;
                        temp_b <= temp_a % temp_b;
                    end else begin
                        result <= temp_a;
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule