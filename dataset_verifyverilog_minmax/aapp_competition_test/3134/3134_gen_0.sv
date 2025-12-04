module matrix_recover(
    input clk,
    input rst_n,
    input [3:0] R,
    input [3:0] C,
    output reg [15:0] matrix,
    output reg valid
);
    // Type definition for function result
    typedef struct {
        bit [15:0] mat;
        bit valid;
    } result_t;

    function automatic result_t solve_matrix(
        input [3:0] R,
        input [3:0] C
    );
        // local variables
        result_t res;
        // check solvability condition: sum of row parity bits must equal sum of column parity bits (mod 2)
        if (^R !== ^C) begin
            res.valid = 1'b0;
            res.mat = 16'h0;
            return res;
        end
        // start with all ones (max ones)
        bit [15:0] mat = '1;
        // parity of flips (number of zeros) for each row and column
        bit [3:0] row_flip_par = 4'b0;
        bit [3:0] col_flip_par = 4'b0;
        // remaining bits to be assigned in each row/col
        bit [3:0] row_rem = 4'b0100; // 4
        bit [3:0] col_rem = 4'b0100; // 4

        // Process bits from most significant (bit 15, row0_col3) down to least significant (bit 0, row3_col0)
        for (int i = 15; i >= 0; i--) begin
            int row = i / 4;
            int col = i % 4;
            // compute needed parity for row and column given current flips
            bit neededRow = R[row] ^ row_flip_par[row];
            bit neededCol = C[col] ^ col_flip_par[col];
            // remaining bits after this one
            bit remRow = row_rem[row] - 1;
            bit remCol = col_rem[col] - 1;
            // decide whether to flip this bit (set to 0)
            bit do_flip = 1'b0;
            // we must flip if this is the last remaining bit in its row or column and parity is still required
            if ((neededRow && (remRow == 0)) || (neededCol && (remCol == 0))) begin
                do_flip = 1'b1;
            end
            // apply decision
            if (do_flip) begin
                mat[i] = 1'b0; // flip to zero
                row_flip_par[row] = row_flip_par[row] ^ 1'b1;
                col_flip_par[col] = col_flip_par[col] ^ 1'b1;
            end
            // decrement remaining bits count
            row_rem[row] = row_rem[row] - 1;
            col_rem[col] = col_rem[col] - 1;
        end

        // Verify that the resulting matrix satisfies the parity constraints
        for (int r = 0; r < 4; r++) begin
            bit parity = 1'b0;
            for (int c = 0; c < 4; c++) begin
                parity = parity ^ mat[r*4 + c];
            end
            if (parity != R[r]) begin
                res.valid = 1'b0;
                res.mat = 16'h0;
                return res;
            end
        end
        for (int c = 0; c < 4; c++) begin
            bit parity = 1'b0;
            for (int r = 0; r < 4; r++) begin
                parity = parity ^ mat[r*4 + c];
            end
            if (parity != C[c]) begin
                res.valid = 1'b0;
                res.mat = 16'h0;
                return res;
            end
        end
        res.valid = 1'b1;
        res.mat = mat;
    endfunction

    // Combinational computation of the result
    reg [15:0] matrix_computed;
    reg valid_computed;
    always_comb begin
        result_t res = solve_matrix(R, C);
        matrix_computed = res.mat;
        valid_computed = res.valid;
    end

    // State machine and timing control
    typedef enum logic [2:0] {
        IDLE   = 3'b000,
        INIT   = 3'b001,
        ROW_ADJUST = 3'b010,
        COL_ADJUST = 3'b011,
        VERIFY = 3'b100,
        DONE   = 3'b101,
        WAIT   = 3'b110
    } state_t;

    reg [3:0] cnt;
    state_t state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 4'd0;
            state <= IDLE;
            matrix <= 16'h0;
            valid <= 1'b0;
        end else begin
            // count up to 10 cycles after reset deassertion
            if (cnt < 4'd10) cnt <= cnt + 1;
            else cnt <= cnt; // hold at 10
            // state progression based on counter
            case (cnt)
                4'd0: state <= IDLE;
                4'd1: state <= INIT;
                4'd2: state <= ROW_ADJUST;
                4'd3: state <= COL_ADJUST;
                4'd4: state <= VERIFY;
                4'd5: state <= DONE;
                default: state <= WAIT;
            endcase
            // latch the result at the 10th cycle (cnt == 4'd9)
            if (cnt == 4'd9) begin
                matrix <= matrix_computed;
                valid <= valid_computed;
            end
        end
    end

endmodule