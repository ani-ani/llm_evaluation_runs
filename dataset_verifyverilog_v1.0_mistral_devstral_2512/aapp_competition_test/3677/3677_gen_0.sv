module MAX_CLIQUE_FINDER(
    input clk,
    input rst_n,
    input start,
    input [2:0] N,
    input [3:0] K,
    input [63:0] adj_packed,
    output reg [3:0] max_size,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] CHECK     = 3'd2;
    localparam [2:0] UPDATE    = 3'd3;
    localparam [2:0] INCREMENT = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state;
    reg [7:0] subset_mask;
    reg [7:0] max_mask;
    reg is_clique;
    reg [3:0] current_size;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // Combinational function to check if subset is a clique
    wire is_clique_wire;
    wire [3:0] current_size_wire;
    integer i, j;

    always @(*) begin
        is_clique_wire = 1'b1;
        current_size_wire = 0;
        
        // Count number of vertices in subset
        for (i = 0; i < 8; i = i + 1) begin
            if (subset_mask[i] && i < N) begin
                current_size_wire = current_size_wire + 1;
            end
        end
        
        // Check all pairs in subset
        for (i = 0; i < 8; i = i + 1) begin
            if (subset_mask[i] && i < N) begin
                for (j = i + 1; j < 8; j = j + 1) begin
                    if (subset_mask[j] && j < N) begin
                        if (!adj_packed[i*8 + j]) begin
                            is_clique_wire = 1'b0;
                        end
                    end
                end
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            subset_mask <= 8'd0;
            max_mask <= 8'd0;
            max_size <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    subset_mask <= 8'd1;
                    max_mask <= (1 << N) - 1;
                    max_size <= 4'd0;
                    state <= CHECK;
                end
                
                CHECK: begin
                    state <= UPDATE;
                end
                
                UPDATE: begin
                    if (is_clique_wire) begin
                        if (current_size_wire > max_size) begin
                            max_size <= current_size_wire;
                        end
                        // Early exit if K is found
                        if (current_size_wire >= K) begin
                            state <= DONE_STATE;
                        end else begin
                            state <= INCREMENT;
                        end
                    end else begin
                        state <= INCREMENT;
                    end
                end
                
                INCREMENT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (subset_mask == max_mask || cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end else begin
                        subset_mask <= subset_mask + 8'd1;
                        state <= CHECK;
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

    // Assign combinational outputs to registers
    always @(*) begin
        is_clique = is_clique_wire;
        current_size = current_size_wire;
    end

endmodule