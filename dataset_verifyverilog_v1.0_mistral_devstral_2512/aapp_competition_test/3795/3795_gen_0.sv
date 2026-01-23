module currency_exchange(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] n,
    input wire [7:0] d,
    input wire [7:0] e,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE_N_MOD = 4'd1;
    localparam [3:0] LOOP_INIT = 4'd2;
    localparam [3:0] LOOP_BODY = 4'd3;
    localparam [3:0] LOOP_CHECK = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;

    reg [3:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Input registers
    reg [31:0] n_reg;
    reg [7:0] d_reg;
    reg [7:0] e_reg;

    // Computation registers
    reg [9:0] B; // 5 * e (max 500)
    reg [7:0] n_mod_d;
    reg [7:0] i; // loop counter (0 to d-1)
    reg [15:0] iB; // j*B (max 100*500=50000)
    reg [7:0] iB_mod_d;
    reg [7:0] min_rem;
    reg [7:0] rem;
    reg [7:0] bit_counter;
    reg [31:0] temp_n;
    reg [31:0] remainder_temp;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            n_reg <= 32'd0;
            d_reg <= 8'd0;
            e_reg <= 8'd0;
            B <= 10'd0;
            n_mod_d <= 8'd0;
            i <= 8'd0;
            iB <= 16'd0;
            iB_mod_d <= 8'd0;
            min_rem <= 8'd255;
            rem <= 8'd0;
            bit_counter <= 8'd0;
            temp_n <= 32'd0;
            remainder_temp <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Capture inputs
                        n_reg <= n;
                        d_reg <= d;
                        e_reg <= e;
                        state <= COMPUTE_N_MOD;
                    end
                end

                COMPUTE_N_MOD: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (bit_counter == 8'd0) begin
                        temp_n <= n_reg;
                        remainder_temp <= 32'd0;
                        bit_counter <= 8'd31;
                    end else begin
                        bit_counter <= bit_counter - 8'd1;
                        remainder_temp <= remainder_temp << 1;
                        remainder_temp[0] <= temp_n[bit_counter];
                        if (remainder_temp >= d_reg) begin
                            remainder_temp <= remainder_temp - d_reg;
                        end
                        if (bit_counter == 8'd0) begin
                            n_mod_d <= remainder_temp[7:0];
                            state <= LOOP_INIT;
                        end
                    end
                end

                LOOP_INIT: begin
                    cycle_count <= cycle_count + 8'd1;
                    B <= 5'd5 * e_reg;
                    min_rem <= 8'd255;
                    i <= 8'd0;
                    iB <= 16'd0;
                    iB_mod_d <= 8'd0;
                    state <= LOOP_CHECK;
                end

                LOOP_CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (iB > n_reg || i == d_reg - 8'd1) begin
                        state <= DONE_STATE;
                    end else begin
                        state <= LOOP_BODY;
                    end
                end

                LOOP_BODY: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute rem = (n_mod_d - iB_mod_d) mod d_reg
                    if (n_mod_d >= iB_mod_d) begin
                        rem <= n_mod_d - iB_mod_d;
                    end else begin
                        rem <= n_mod_d + d_reg - iB_mod_d;
                    end

                    // Update min_rem
                    if (rem < min_rem) begin
                        min_rem <= rem;
                    end

                    // Increment i and update iB_mod_d
                    i <= i + 8'd1;
                    iB <= iB + B;
                    if (iB_mod_d + B[7:0] >= d_reg) begin
                        iB_mod_d <= iB_mod_d + B[7:0] - d_reg;
                    end else begin
                        iB_mod_d <= iB_mod_d + B[7:0];
                    end

                    state <= LOOP_CHECK;
                end

                DONE_STATE: begin
                    result <= min_rem;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule