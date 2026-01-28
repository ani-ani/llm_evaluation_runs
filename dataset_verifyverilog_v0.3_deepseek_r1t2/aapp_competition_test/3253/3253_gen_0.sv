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

    // Constants
    localparam [DATA_WIDTH-1:0] INF = 32'h7FFFFFFF;
    
    // State declarations
    localparam [2:0] S_IDLE = 3'd0,
                     S_START_MASK = 3'd1,
                     S_ADD_STATE = 3'd2,
                     S_CHECK = 3'd3,
                     S_DONE = 3'd4;
    
    // Cost wires
    wire [DATA_WIDTH-1:0] cost_wire [MAX_S-1:0];
    
    // Generate cost calculation for each state
    genvar i;
    generate
        for (i=0; i<MAX_S; i=i+1) begin : gen_cost
            assign cost_wire[i] = calc_cost(C[i], F[i], U[i]);
        end
    endgenerate
    
    // Combinational logic for delegate totals
    wire [DELEGATE_WIDTH-1:0] total_delegates_comb = 
        (S >=4'd1 ? D[0] : 0) + 
        (S >=4'd2 ? D[1] : 0) + 
        (S >=4'd3 ? D[2] : 0) + 
        (S >=4'd4 ? D[3] : 0) + 
        (S >=4'd5 ? D[4] : 0) + 
        (S >=4'd6 ? D[5] : 0) + 
        (S >=4'd7 ? D[6] : 0) + 
        (S >=4'd8 ? D[7] : 0);
    
    wire [DELEGATE_WIDTH-1:0] required_comb = (total_delegates_comb >> 1) + 1;
    wire [7:0] max_mask_comb = (8'b00000001 << S) - 1;
    
    // Internal registers
    reg [2:0] state;
    reg [7:0] mask;
    reg [2:0] idx;
    reg [DELEGATE_WIDTH-1:0] sum_delegates;
    reg [DATA_WIDTH-1:0] sum_cost;
    reg [DATA_WIDTH-1:0] min_cost;
    reg [3:0] S_latched;
    reg [DELEGATE_WIDTH-1:0] D_latched [MAX_S-1:0];
    reg [DATA_WIDTH-1:0] cost_latched [MAX_S-1:0];
    reg [DELEGATE_WIDTH-1:0] total_delegates_latched;
    reg [DELEGATE_WIDTH-1:0] required_latched;
    reg [7:0] max_mask_latched;
    
    // Cost calculation function
    function automatic [DATA_WIDTH-1:0] calc_cost;
        input [DATA_WIDTH-1:0] C_val, F_val, U_val;
        reg [DATA_WIDTH:0] diff;
        begin
            if (C_val > (F_val + U_val))
                calc_cost = 32'd0;
            else if ((C_val + U_val) <= F_val)
                calc_cost = INF;
            else begin
                diff = (F_val + U_val) - C_val;
                calc_cost = (diff >> 1) + 1;
            end
        end
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= S_IDLE;
            done <= 1'b0;
            result <= 32'd0;
            mask <= 8'd0;
            idx <= 3'd0;
            sum_delegates <= 12'd0;
            sum_cost <= 32'd0;
            min_cost <= INF;
            S_latched <= 4'd0;
            total_delegates_latched <= 12'd0;
            required_latched <= 12'd0;
            max_mask_latched <= 8'd0;
            
            // Initialize arrays
            D_latched[0] <= 12'd0; cost_latched[0] <= INF;
            D_latched[1] <= 12'd0; cost_latched[1] <= INF;
            D_latched[2] <= 12'd0; cost_latched[2] <= INF;
            D_latched[3] <= 12'd0; cost_latched[3] <= INF;
            D_latched[4] <= 12'd0; cost_latched[4] <= INF;
            D_latched[5] <= 12'd0; cost_latched[5] <= INF;
            D_latched[6] <= 12'd0; cost_latched[6] <= INF;
            D_latched[7] <= 12'd0; cost_latched[7] <= INF;
        end
        else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        S_latched <= S;
                        total_delegates_latched <= total_delegates_comb;
                        required_latched <= required_comb;
                        max_mask_latched <= max_mask_comb;
                        
                        // Latch input arrays based on S
                        D_latched[0] <= (S >=4'd1) ? D[0] : 12'd0;
                        cost_latched[0] <= (S >=4'd1) ? cost_wire[0] : INF;
                        
                        D_latched[1] <= (S >=4'd2) ? D[1] : 12'd0;
                        cost_latched[1] <= (S >=4'd2) ? cost_wire[1] : INF;
                        
                        D_latched[2] <= (S >=4'd3) ? D[2] : 12'd0;
                        cost_latched[2] <= (S >=4'd3) ? cost_wire[2] : INF;
                        
                        D_latched[3] <= (S >=4'd4) ? D[3] : 12'd0;
                        cost_latched[3] <= (S >=4'd4) ? cost_wire[3] : INF;
                        
                        D_latched[4] <= (S >=4'd5) ? D[4] : 12'd0;
                        cost_latched[4] <= (S >=4'd5) ? cost_wire[4] : INF;
                        
                        D_latched[5] <= (S >=4'd6) ? D[5] : 12'd0;
                        cost_latched[5] <= (S >=4'd6) ? cost_wire[5] : INF;
                        
                        D_latched[6] <= (S >=4'd7) ? D[6] : 12'd0;
                        cost_latched[6] <= (S >=4'd7) ? cost_wire[6] : INF;
                        
                        D_latched[7] <= (S >=4'd8) ? D[7] : 12'd0;
                        cost_latched[7] <= (S >=4'd8) ? cost_wire[7] : INF;
                        
                        mask <= 8'd1;  // Start at first valid mask
                        min_cost <= INF;
                        state <= S_START_MASK;
                    end
                end
                
                S_START_MASK: begin
                    sum_delegates <= 12'd0;
                    sum_cost <= 32'd0;
                    idx <= 3'd0;
                    state <= S_ADD_STATE;
                end
                
                S_ADD_STATE: begin
                    if (idx < S_latched) begin
                        if (mask[idx]) begin
                            sum_delegates <= sum_delegates + D_latched[idx];
                            sum_cost <= sum_cost + cost_latched[idx];
                        end
                        idx <= idx + 1;
                        state <= S_ADD_STATE;
                    end
                    else begin
                        state <= S_CHECK;
                    end
                end
                
                S_CHECK: begin
                    if (sum_delegates >= required_latched) begin
                        if (sum_cost < min_cost)
                            min_cost <= sum_cost;
                    end
                    
                    if (mask != max_mask_latched) begin
                        mask <= mask + 1;
                        state <= S_START_MASK;
                    end
                    else begin
                        state <= S_DONE;
                    end
                end
                
                S_DONE: begin
                    result <= min_cost;
                    done <= 1'b1;
                    state <= S_IDLE;
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule