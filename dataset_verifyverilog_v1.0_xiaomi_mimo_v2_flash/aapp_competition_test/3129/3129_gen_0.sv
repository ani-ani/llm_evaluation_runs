module haybale_sort (
    input clk,
    input rst_n,
    input start,
    input [7:0] s,   // 0 = C, 1 = P
    output reg [3:0] result,
    output reg done
);
    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE    = 2'd2;
    
    reg [1:0] state;
    
    // Combinational logic registers
    reg [4:0] inv;              // inversion count, up to 16
    reg has_2_inv;              // 1 if any triple with 2 inversions exists
    reg [4:0] ceil_half;        // ceil(inv/2)
    reg [3:0] result_comb;      // combinational result
    reg [2:0] zeros_suffix [0:8]; // suffix zero count, index 8 = 0
    
    integer i;
    
    always @(*) begin
        // Compute suffix zeros
        zeros_suffix[8] = 3'd0;
        for (i = 7; i >= 0; i = i - 1) begin
            zeros_suffix[i] = zeros_suffix[i+1] + (s[i] ? 3'd0 : 3'd1);
        end
        
        // Compute inversion count
        inv = 5'd0;
        for (i = 0; i < 8; i = i + 1) begin
            if (s[i]) begin
                inv = inv + {1'b0, zeros_suffix[i+1]};
            end
        end
        
        // Check for PCC or PPC
        has_2_inv = 1'b0;
        for (i = 0; i <= 5; i = i + 1) begin
            if ((s[i] && !s[i+1] && !s[i+2]) || (s[i] && s[i+1] && !s[i+2])) begin
                has_2_inv = 1'b1;
            end
        end
        
        // Compute ceil(inv/2)
        ceil_half = (inv + 5'd1) >> 1;
        
        // Compute final result
        if (inv == 5'd0) begin
            result_comb = 4'd0;
        end else if (has_2_inv) begin
            result_comb = ceil_half[3:0];
        end else if (inv[0]) begin  // odd
            result_comb = ceil_half[3:0];
        end else begin
            result_comb = ceil_half[3:0] + 4'd1;
        end
    end
    
    // Sequential state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    result <= result_comb;
                    state <= DONE;
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule