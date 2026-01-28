module vault_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] A,
    input wire [4:0] B,
    input wire [10:0] L,
    output reg [21:0] insecure_cnt,
    output reg [21:0] secure_cnt,
    output reg [21:0] supersecure_cnt,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_GCD = 3'd1;
    localparam [2:0] COUNT_VAULTS = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    
    // GCD computation pipeline
    reg [4:0] k;
    reg [10:0] gcd_reg [0:15];
    reg [10:0] a_reg [0:15], b_reg [0:15];
    reg [4:0] k_reg [0:15];
    reg [4:0] k_max;
    reg [4:0] k_counter;
    
    // Vault counting
    reg [10:0] x_counter;
    reg [4:0] y_counter;
    reg [4:0] total_k;
    reg [4:0] current_k;
    reg gcd_k1, gcd_k2;
    
    // Counters
    reg [21:0] ins_cnt, sec_cnt, sup_cnt;
    
    // Compute total_k = A + B
    always @(*) begin
        total_k = A + B;
    end
    
    // GCD computation using Euclidean algorithm
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            k <= 5'd0;
            k_counter <= 5'd0;
            x_counter <= 11'd0;
            y_counter <= 5'd0;
            current_k <= 5'd0;
            ins_cnt <= 22'd0;
            sec_cnt <= 22'd0;
            sup_cnt <= 22'd0;
            done <= 1'b0;
            
            // Initialize pipeline registers
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                gcd_reg[i] <= 11'd0;
                a_reg[i] <= 11'd0;
                b_reg[i] <= 11'd0;
                k_reg[i] <= 5'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= COMPUTE_GCD;
                        k_counter <= 5'd0;
                        k_max <= total_k;
                    end
                end
                
                COMPUTE_GCD: begin
                    // Pipeline stage 0: load new k value
                    if (k_counter < k_max) begin
                        a_reg[0] <= L;
                        b_reg[0] <= k_counter + 5'd1;
                        k_reg[0] <= k_counter + 5'd1;
                        k_counter <= k_counter + 5'd1;
                    end
                    
                    // Pipeline stages 1-15: compute gcd
                    integer i;
                    for (i = 1; i < 16; i = i + 1) begin
                        if (b_reg[i-1] != 11'd0) begin
                            if (a_reg[i-1] > b_reg[i-1]) begin
                                a_reg[i] <= a_reg[i-1] % b_reg[i-1];
                                b_reg[i] <= b_reg[i-1];
                            end else begin
                                a_reg[i] <= b_reg[i-1] % a_reg[i-1];
                                b_reg[i] <= a_reg[i-1];
                            end
                            k_reg[i] <= k_reg[i-1];
                        end else begin
                            a_reg[i] <= 11'd0;
                            b_reg[i] <= 11'd0;
                            k_reg[i] <= 5'd0;
                        end
                    end
                    
                    // Store result in gcd_reg
                    for (i = 0; i < 16; i = i + 1) begin
                        if (b_reg[i] == 11'd0 && a_reg[i] != 11'd0) begin
                            gcd_reg[i] <= a_reg[i];
                        end else if (a_reg[i] == 11'd0 && b_reg[i] != 11'd0) begin
                            gcd_reg[i] <= b_reg[i];
                        end else if (a_reg[i] == 11'd0 && b_reg[i] == 11'd0) begin
                            gcd_reg[i] <= 11'd0;
                        end
                    end
                    
                    // Check if all gcds are computed
                    if (k_counter >= k_max && gcd_reg[15] != 11'd0) begin
                        next_state <= COUNT_VAULTS;
                        x_counter <= 11'd1;
                        y_counter <= 5'd0;
                    end
                end
                
                COUNT_VAULTS: begin
                    // Process each vault at (x_counter, y_counter)
                    current_k <= y_counter + 5'd1;
                    
                    // Check visibility conditions
                    gcd_k1 = (gcd_reg[15] == 11'd1) ? 1'b1 : 1'b0;
                    gcd_k2 = (gcd_reg[15] == 11'd1) ? 1'b1 : 1'b0;
                    
                    // Update counters based on conditions
                    if (!gcd_k1 && !gcd_k2) begin
                        ins_cnt <= ins_cnt + 22'd1;
                    end else if (gcd_k1 ^ gcd_k2) begin
                        sec_cnt <= sec_cnt + 22'd1;
                    end else begin
                        sup_cnt <= sup_cnt + 22'd1;
                    end
                    
                    // Move to next vault
                    if (y_counter < total_k) begin
                        y_counter <= y_counter + 5'd1;
                    end else begin
                        y_counter <= 5'd0;
                        if (x_counter < L) begin
                            x_counter <= x_counter + 11'd1;
                        end else begin
                            next_state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    insecure_cnt <= ins_cnt;
                    secure_cnt <= sec_cnt;
                    supersecure_cnt <= sup_cnt;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
    
    // Helper function for gcd (not used in pipeline, but for reference)
    function [10:0] compute_gcd;
        input [10:0] a, b;
        reg [10:0] x, y;
        begin
            x = a;
            y = b;
            while (y != 11'd0) begin
                if (x > y) begin
                    x = x % y;
                end else begin
                    y = y % x;
                end
            end
            compute_gcd = (x == 11'd0) ? y : x;
        end
    endfunction

endmodule