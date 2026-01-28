module LuckyPermutationTriple (
    input clk,
    input rst_n,
    input start,
    input [4:0] n_in,
    output reg valid,
    output reg [4:0] addr_a,
    output reg [4:0] addr_b,
    output reg [4:0] addr_c,
    output reg [4:0] data_a,
    output reg [4:0] data_b,
    output reg [4:0] data_c,
    output reg wr_en,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_N = 3'd1;
    localparam [2:0] INVALID = 3'd2;
    localparam [2:0] WRITE_ADDR = 3'd3;
    localparam [2:0] WRITE_DATA = 3'd4;
    localparam [2:0] INCREMENT = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    reg [2:0] state;
    reg [4:0] n_val;
    reg [4:0] i;
    reg [4:0] sum_i_i;
    reg [4:0] data_c_reg;

    // Synchronous logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            done <= 1'b0;
            wr_en <= 1'b0;
            n_val <= 5'd0;
            i <= 5'd0;
            sum_i_i <= 5'd0;
            data_c_reg <= 5'd0;
            addr_a <= 5'd0;
            addr_b <= 5'd0;
            addr_c <= 5'd0;
            data_a <= 5'd0;
            data_b <= 5'd0;
            data_c <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    wr_en <= 1'b0;
                    if (start) begin
                        n_val <= n_in;
                        i <= 5'd0;
                        state <= CHECK_N;
                    end
                end

                CHECK_N: begin
                    // Check if n is even (LSB is 0)
                    if (n_val[0] == 1'b0) begin
                        valid <= 1'b0;
                        state <= INVALID;
                    end else begin
                        valid <= 1'b1;
                        state <= WRITE_ADDR;
                    end
                end

                INVALID: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                WRITE_ADDR: begin
                    // Setup address and identity data for a and b
                    addr_a <= i;
                    data_a <= i;
                    addr_b <= i;
                    data_b <= i;
                    
                    // Calculate c value: (i + i) % n
                    // Sum i + i (shift left by 1)
                    sum_i_i <= {i[3:0], 1'b0}; // i * 2
                    state <= WRITE_DATA;
                end

                WRITE_DATA: begin
                    // Calculate modulo n: if sum >= n, subtract n
                    // Since max i is n-1, max sum is 2n-2. Result is < n.
                    if (sum_i_i >= n_val) begin
                        data_c_reg <= sum_i_i - n_val;
                    end else begin
                        data_c_reg <= sum_i_i;
                    end
                    
                    // Setup address c
                    addr_c <= i;
                    state <= INCREMENT;
                end

                INCREMENT: begin
                    // Update data_c with computed value
                    data_c <= data_c_reg;
                    // Assert write enable for one cycle
                    wr_en <= 1'b1;
                    
                    // Increment counter
                    i <= i + 5'd1;
                    
                    // Check if finished
                    if (i == n_val - 5'd1) begin
                        state <= FINISH;
                    end else begin
                        state <= WRITE_ADDR;
                    end
                end

                FINISH: begin
                    wr_en <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule