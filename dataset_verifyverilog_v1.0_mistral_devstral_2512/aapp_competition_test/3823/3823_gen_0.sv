module jeff_rounding(
    input clk,
    input rst_n,
    input start,
    input [31:0] data_in,
    input data_valid,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] READ_N    = 3'd1;
    localparam [2:0] READ_DATA = 3'd2;
    localparam [2:0] COMPUTE   = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    // Registers
    reg [2:0] state, next_state;
    reg [31:0] n;
    reg [31:0] m;
    reg [31:0] T;
    reg [31:0] x;
    reg [31:0] min_diff;
    reg [31:0] current_diff;
    reg [31:0] L;
    reg [31:0] R;
    reg [31:0] count;
    reg [31:0] data_reg;
    reg [31:0] fractional;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n <= 32'd0;
            m <= 32'd0;
            T <= 32'd0;
            x <= 32'd0;
            min_diff <= 32'd0;
            current_diff <= 32'd0;
            L <= 32'd0;
            R <= 32'd0;
            count <= 32'd0;
            data_reg <= 32'd0;
            fractional <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= READ_N;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                READ_N: begin
                    if (data_valid) begin
                        n <= data_in;
                        count <= 32'd0;
                        m <= 32'd0;
                        T <= 32'd0;
                        next_state <= READ_DATA;
                    end else begin
                        next_state <= READ_N;
                    end
                end

                READ_DATA: begin
                    if (data_valid) begin
                        data_reg <= data_in;
                        fractional <= data_reg % 32'd1000;
                        if (fractional != 32'd0) begin
                            m <= m + 32'd1;
                            T <= T + fractional;
                        end
                        count <= count + 32'd1;
                        if (count == (n << 1)) begin
                            L <= (m > n) ? (m - n) : 32'd0;
                            R <= (m < n) ? m : n;
                            x <= L;
                            min_diff <= 32'd3276800000;
                            next_state <= COMPUTE;
                        end else begin
                            next_state <= READ_DATA;
                        end
                    end else begin
                        next_state <= READ_DATA;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    current_diff <= (x * 32'd1000) - T;
                    if (current_diff[31]) begin
                        current_diff <= -current_diff;
                    end
                    if (current_diff < min_diff) begin
                        min_diff <= current_diff;
                    end
                    x <= x + 32'd1;
                    if (x > R || cycle_count >= MAX_CYCLES) begin
                        result <= min_diff;
                        next_state <= FINISH;
                    end else begin
                        next_state <= COMPUTE;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end
endmodule