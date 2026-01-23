module haybale_sort (
    input clk,
    input rst_n,
    input start,
    input [7:0] s,
    output reg [3:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;
    
    // Combinational logic for inversion count
    reg [4:0] inv;
    reg has_2_inv;
    reg [4:0] ceil_half;
    reg [3:0] result_comb;
    
    integer i;
    reg [2:0] zeros_suffix [0:8];
    
    always_comb begin
        zeros_suffix[8] = 3'd0;
        for (i = 7; i >= 0; i = i - 1) begin
            zeros_suffix[i] = zeros_suffix[i+1] + (s[i] ? 3'd0 : 3'd1);
        end
        
        inv = 5'd0;
        for (i = 0; i < 8; i = i + 1) begin
            if (s[i]) inv = inv + zeros_suffix[i+1];
        end
    end
    
    always_comb begin
        has_2_inv = 1'b0;
        for (i = 0; i <= 5; i = i + 1) begin
            if ((s[i] && !s[i+1] && !s[i+2]) || (s[i] && s[i+1] && !s[i+2]))
                has_2_inv = 1'b1;
        end
    end
    
    always_comb begin
        ceil_half = (inv + 1) >> 1;
    end
    
    always_comb begin
        if (inv == 5'd0)
            result_comb = 4'd0;
        else if (has_2_inv)
            result_comb = ceil_half[4:1];
        else if (inv[0])
            result_comb = ceil_half[4:1];
        else
            result_comb = ceil_half[4:1] + 4'd1;
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    result <= result_comb;
                    
                    if (cycle_count >= MAX_CYCLES) begin
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