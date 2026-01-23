module election #(
    parameter MAX_S = 8,
    parameter DATA_WIDTH = 32,
    parameter DELEGATE_WIDTH = 12
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] S,
    input wire [DELEGATE_WIDTH-1:0] D [MAX_S-1:0],
    input wire [DATA_WIDTH-1:0] C [MAX_S-1:0],
    input wire [DATA_WIDTH-1:0] F [MAX_S-1:0],
    input wire [DATA_WIDTH-1:0] U [MAX_S-1:0],
    output reg [DATA_WIDTH-1:0] result,
    output reg done
);

    localparam [DATA_WIDTH-1:0] INF = 32'h7FFFFFFF;
    
    // Combinational cost calculation function
    function automatic [DATA_WIDTH-1:0] calc_cost;
        input [DATA_WIDTH-1:0] C_val;
        input [DATA_WIDTH-1:0] F_val;
        input [DATA_WIDTH-1:0] U_val;
        begin
            if (C_val > F_val + U_val) begin
                calc_cost = 0;
            end else if (C_val + U_val <= F_val) begin
                calc_cost = INF;
            end else begin
                calc_cost = ((F_val + U_val - C_val) >> 1) + 1;
            end
        end
    endfunction

    // State definitions
    localparam [2:0] S_IDLE = 3'd0;
    localparam [2:0] S_LATCH = 3'd1;
    localparam [2:0] S_START_MASK = 3'd2;
    localparam [2:0] S_ITERATE = 3'd3;
    localparam [2:0] S_CHECK = 3'd4;
    localparam [2:0] S_DONE = 3'd5;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    reg [7:0] mask;
    reg [2:0] i;
    reg [DELEGATE_WIDTH-1:0] sum_delegates;
    reg [DATA_WIDTH-1:0] sum_cost;
    reg [DATA_WIDTH-1:0] min_cost;
    
    // Latched input values
    reg [3:0] S_latched;
    reg [DELEGATE_WIDTH-1:0] D_latched [MAX_S-1:0];
    reg [DATA_WIDTH-1:0] cost_latched [MAX_S-1:0];
    
    // Combinational wire for total delegates
    wire [DELEGATE_WIDTH-1:0] total_delegates;
    assign total_delegates = D[0] + D[1] + D[2] + D[3] + D[4] + D[5] + D[6] + D[7];
    
    // Next state logic
    always @(*) begin
        next_state = state; // Default
        case (state)
            S_IDLE: begin
                if (start) next_state = S_LATCH;
            end
            S_LATCH: begin
                next_state = S_START_MASK;
            end
            S_START_MASK: begin
                next_state = S_ITERATE;
            end
            S_ITERATE: begin
                if (i < S_latched) next_state = S_ITERATE;
                else next_state = S_CHECK;
            end
            S_CHECK: begin
                if (mask < ((8'b00000001 << S_latched) - 1)) next_state = S_START_MASK;
                else next_state = S_DONE;
            end
            S_DONE: begin
                next_state = S_IDLE;
            end
            default: next_state = S_IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 1'b0;
            result <= 32'd0;
            mask <= 8'd0;
            i <= 3'd0;
            sum_delegates <= 12'd0;
            sum_cost <= 32'd0;
            min_cost <= INF;
            S_latched <= 4'd0;
            // Initialize latched arrays
            D_latched[0] <= 12'd0; D_latched[1] <= 12'd0; D_latched[2] <= 12'd0; D_latched[3] <= 12'd0;
            D_latched[4] <= 12'd0; D_latched[5] <= 12'd0; D_latched[6] <= 12'd0; D_latched[7] <= 12'd0;
            cost_latched[0] <= 32'd0; cost_latched[1] <= 32'd0; cost_latched[2] <= 32'd0; cost_latched[3] <= 32'd0;
            cost_latched[4] <= 32'd0; cost_latched[5] <= 32'd0; cost_latched[6] <= 32'd0; cost_latched[7] <= 32'd0;
        end else begin
            state <= next_state;
            
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        mask <= 8'd0;
                        i <= 3'd0;
                        sum_delegates <= 12'd0;
                        sum_cost <= 32'd0;
                        min_cost <= INF;
                    end
                end
                
                S_LATCH: begin
                    S_latched <= S;
                    // Latch delegate and cost arrays
                    D_latched[0] <= D[0]; D_latched[1] <= D[1]; D_latched[2] <= D[2]; D_latched[3] <= D[3];
                    D_latched[4] <= D[4]; D_latched[5] <= D[5]; D_latched[6] <= D[6]; D_latched[7] <= D[7];
                    cost_latched[0] <= calc_cost(C[0], F[0], U[0]);
                    cost_latched[1] <= calc_cost(C[1], F[1], U[1]);
                    cost_latched[2] <= calc_cost(C[2], F[2], U[2]);
                    cost_latched[3] <= calc_cost(C[3], F[3], U[3]);
                    cost_latched[4] <= calc_cost(C[4], F[4], U[4]);
                    cost_latched[5] <= calc_cost(C[5], F[5], U[5]);
                    cost_latched[6] <= calc_cost(C[6], F[6], U[6]);
                    cost_latched[7] <= calc_cost(C[7], F[7], U[7]);
                end
                
                S_START_MASK: begin
                    i <= 3'd0;
                    sum_delegates <= 12'd0;
                    sum_cost <= 32'd0;
                end
                
                S_ITERATE: begin
                    if (i < S_latched) begin
                        if (mask[i]) begin
                            sum_delegates <= sum_delegates + D_latched[i];
                            sum_cost <= sum_cost + cost_latched[i];
                        end
                        i <= i + 3'd1;
                    end
                end
                
                S_CHECK: begin
                    if (sum_delegates >= (total_delegates[DELEGATE_WIDTH-1:1] + 1)) begin
                        if (sum_cost < min_cost) begin
                            min_cost <= sum_cost;
                        end
                    end
                    mask <= mask + 8'd1;
                end
                
                S_DONE: begin
                    result <= min_cost;
                    done <= 1'b1;
                end
                
                default: begin
                    // Already handled in next_state
                end
            endcase
        end
    end

endmodule