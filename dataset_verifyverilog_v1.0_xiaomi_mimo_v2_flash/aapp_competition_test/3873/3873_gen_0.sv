module permutation_swapper (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg possible,
    output reg valid,
    output reg [7:0] a,
    output reg [7:0] b,
    output reg done
);

// State definitions
localparam [3:0] IDLE    = 4'd0;
localparam [3:0] CHECK   = 4'd1;
localparam [3:0] X0_FWD  = 4'd2;
localparam [3:0] X0_SWAP = 4'd3;
localparam [3:0] X0_BWD  = 4'd4;
localparam [3:0] X1_FWD  = 4'd5;
localparam [3:0] X1_SWAP = 4'd6;
localparam [3:0] X1_BWD  = 4'd7;
localparam [3:0] FINAL1  = 4'd8;
localparam [3:0] FINAL2  = 4'd9;
localparam [3:0] FINAL3  = 4'd10;
localparam [3:0] FINAL4  = 4'd11;
localparam [3:0] NEXT_I  = 4'd12;
localparam [3:0] DONE    = 4'd13;

reg [3:0] state;
reg [7:0] i_reg;      // current block start index (0-indexed)
reg [7:0] j_reg;      // counter for j loops
reg [1:0] x_reg;      // current x (0 or 1)
reg [1:0] final_cnt;  // 0..3 for final swaps
reg [7:0] n_reg;      // stored n

// Helper: n mod 4
wire [1:0] n_mod4 = n[1:0];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        possible <= 1'b0;
        valid <= 1'b0;
        a <= 8'd0;
        b <= 8'd0;
        done <= 1'b0;
        i_reg <= 8'd0;
        j_reg <= 8'd0;
        x_reg <= 2'd0;
        final_cnt <= 2'd0;
        n_reg <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                valid <= 1'b0;
                if (start) begin
                    n_reg <= n;
                    state <= CHECK;
                end
            end

            CHECK: begin
                // Determine possibility
                if (n_mod4 == 2'd0 || n_mod4 == 2'd1) begin
                    possible <= 1'b1;
                    i_reg <= {6'd0, n_mod4}; // n%4 (0 or 1)
                    if ({6'd0, n_mod4} >= n_reg) begin
                        // No swaps needed (n=1)
                        state <= DONE;
                    end else begin
                        state <= X0_FWD;
                        j_reg <= 8'd0;
                    end
                end else begin
                    possible <= 1'b0;
                    state <= DONE;
                end
            end

            // X=0 forward loop
            X0_FWD: begin
                if (j_reg < i_reg) begin
                    valid <= 1'b1;
                    a <= j_reg + 8'd1;           // 1-indexed
                    b <= i_reg + 8'd1;           // i+0 +1
                    j_reg <= j_reg + 8'd1;
                    state <= X0_FWD;
                end else begin
                    valid <= 1'b0;
                    j_reg <= 8'd0;
                    state <= X0_SWAP;
                end
            end

            X0_SWAP: begin
                valid <= 1'b1;
                a <= i_reg + 8'd1;               // i+0 +1
                b <= i_reg + 8'd2;               // i+1 +1
                state <= X0_BWD;
            end

            X0_BWD: begin
                if (j_reg < i_reg) begin
                    valid <= 1'b1;
                    a <= j_reg + 8'd1;
                    b <= i_reg + 8'd2;           // i+1 +1
                    j_reg <= j_reg + 8'd1;
                    state <= X0_BWD;
                end else begin
                    valid <= 1'b0;
                    j_reg <= 8'd0;
                    state <= X1_FWD;
                end
            end

            // X=1 forward loop
            X1_FWD: begin
                if (j_reg < i_reg) begin
                    valid <= 1'b1;
                    a <= j_reg + 8'd1;
                    b <= i_reg + 8'd3;           // i+2 +1
                    j_reg <= j_reg + 8'd1;
                    state <= X1_FWD;
                end else begin
                    valid <= 1'b0;
                    j_reg <= 8'd0;
                    state <= X1_SWAP;
                end
            end

            X1_SWAP: begin
                valid <= 1'b1;
                a <= i_reg + 8'd3;               // i+2 +1
                b <= i_reg + 8'd4;               // i+3 +1
                state <= X1_BWD;
            end

            X1_BWD: begin
                if (j_reg < i_reg) begin
                    valid <= 1'b1;
                    a <= j_reg + 8'd1;
                    b <= i_reg + 8'd4;           // i+3 +1
                    j_reg <= j_reg + 8'd1;
                    state <= X1_BWD;
                end else begin
                    valid <= 1'b0;
                    final_cnt <= 2'd0;
                    state <= FINAL1;
                end
            end

            FINAL1: begin
                valid <= 1'b1;
                a <= i_reg + 8'd1;               // i +1
                b <= i_reg + 8'd4;               // i+3 +1
                final_cnt <= 2'd1;
                state <= FINAL2;
            end

            FINAL2: begin
                valid <= 1'b1;
                a <= i_reg + 8'd2;               // i+1 +1
                b <= i_reg + 8'd3;               // i+2 +1
                final_cnt <= 2'd2;
                state <= FINAL3;
            end

            FINAL3: begin
                valid <= 1'b1;
                a <= i_reg + 8'd1;               // i +1
                b <= i_reg + 8'd3;               // i+2 +1
                final_cnt <= 2'd3;
                state <= FINAL4;
            end

            FINAL4: begin
                valid <= 1'b1;
                a <= i_reg + 8'd2;               // i+1 +1
                b <= i_reg + 8'd4;               // i+3 +1
                state <= NEXT_I;
            end

            NEXT_I: begin
                valid <= 1'b0;
                i_reg <= i_reg + 8'd4;
                if (i_reg + 8'd4 < n_reg) begin
                    state <= X0_FWD;
                    j_reg <= 8'd0;
                end else begin
                    state <= DONE;
                end
            end

            DONE: begin
                done <= 1'b1;
                valid <= 1'b0;
                state <= DONE; // stay in DONE
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule