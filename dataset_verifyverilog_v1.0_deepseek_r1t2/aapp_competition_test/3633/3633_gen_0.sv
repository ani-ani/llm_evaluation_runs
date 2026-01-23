module CriticOrderSolver #(
    parameter N = 8,          // Maximum number of critics (1-8)
    parameter M_WIDTH = 4,    // Bits for m (0-15)
    parameter K_WIDTH = 14,   // Bits for k (up to 8*15=120)
    parameter IDX_WIDTH = 3   // Bits for critic indices (0-7)
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [M_WIDTH-1:0] m,
    input wire [K_WIDTH-1:0] k,
    input wire [M_WIDTH-1:0] a [0:N-1],
    output reg done,
    output reg possible,
    output reg [IDX_WIDTH-1:0] p [0:N-1],
    output reg [3:0] valid_indices
);

// State declarations
localparam [2:0] IDLE       = 3'd0;
localparam [2:0] CHECK_COND = 3'd1;
localparam [2:0] SORT       = 3'd2;
localparam [2:0] BUILD_PERM = 3'd3;
localparam [2:0] DONE_STATE = 3'd4;

reg [2:0] state;

// Internal registers
reg [M_WIDTH-1:0] a_sorted [0:N-1];
reg [IDX_WIDTH-1:0] idx_sorted [0:N-1];
reg [3:0] x; // k/m
reg [3:0] loop_counter;
reg [3:0] sort_i, sort_j;
wire k_mod_m_zero;

// Condition check
assign k_mod_m_zero = (k % m == 0);

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        possible <= 1'b0;
        valid_indices <= 4'd0;
        x <= 4'd0;
        loop_counter <= 4'd0;
        sort_i <= 4'd0;
        sort_j <= 4'd0;
        
        for (integer i=0; i<N; i=i+1) begin
            p[i] <= {IDX_WIDTH{1'b0}};
            a_sorted[i] <= {M_WIDTH{1'b0}};
            idx_sorted[i] <= {IDX_WIDTH{1'b0}};
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                possible <= 1'b0;
                if (start) begin
                    state <= CHECK_COND;
                    // Initialize indices
                    for (integer i=0; i<N; i=i+1) idx_sorted[i] <= i[IDX_WIDTH-1:0];
                end
            end

            CHECK_COND: begin
                if (!k_mod_m_zero || (k > (n*m)) || (k == 0) || (k < m)) begin
                    possible <= 1'b0;
                    state <= DONE_STATE;
                end else begin
                    x <= k / m;
                    if (x > n || x == 0) begin
                        possible <= 1'b0;
                        state <= DONE_STATE;
                    end else begin
                        // Copy inputs to a_sorted
                        for (integer i=0; i<N; i=i+1)
                            a_sorted[i] <= a[i];
                        sort_i <= 4'd0;
                        sort_j <= 4'd0;
                        state <= SORT;
                    end
                end
            end

            SORT: begin
                // Bubble sort - one iteration per cycle
                if (sort_j < n-1) begin
                    if (sort_i < n-sort_j-1) begin
                        if (a_sorted[sort_i] < a_sorted[sort_i+1]) begin
                            // Swap values
                            a_sorted[sort_i] <= a_sorted[sort_i+1];
                            a_sorted[sort_i+1] <= a_sorted[sort_i];
                            // Swap indices
                            idx_sorted[sort_i] <= idx_sorted[sort_i+1];
                            idx_sorted[sort_i+1] <= idx_sorted[sort_i];
                        end
                        sort_i <= sort_i + 4'd1;
                    end else begin
                        sort_j <= sort_j + 4'd1;
                        sort_i <= 4'd0;
                    end
                end else begin
                    state <= BUILD_PERM;
                end
            end

            BUILD_PERM: begin
                possible <= 1'b1;
                valid_indices <= n;
                
                // Output first permutation (1-based indices)
                for (integer i=0; i<N; i=i+1) begin
                    if (i < n) begin
                        p[i] <= idx_sorted[i] + 1'b1;
                    end else begin
                        p[i] <= {IDX_WIDTH{1'b0}};
                    end
                end
                
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