module alternating_sum (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] a,
    input wire [7:0] b,
    input wire [3:0] k,
    input wire [7:0] s_sequence,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_R = 3'd1;
    localparam [2:0] COMPUTE_C = 3'd2;
    localparam [2:0] COMPUTE_D = 3'd3;
    localparam [2:0] COMPLETE = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [3:0] counter;
    reg [15:0] sum;
    reg [7:0] r;
    reg [15:0] C;
    reg [15:0] D;
    reg [15:0] a_pow_n;
    reg [7:0] r_k;
    reg [7:0] current_r;
    reg [3:0] bit_pos;
    reg [7:0] base;

    // Combinational signals
    wire [7:0] s_bit;
    wire [15:0] r_temp;
    wire [7:0] r_squared;
    wire [15:0] term_temp;
    wire [15:0] term;

    // Extract current sign bit
    assign s_bit = (s_sequence >> bit_pos) & 8'h01;

    // Compute r_squared
    assign r_temp = r * r;
    assign r_squared = r_temp[7:0];

    // Compute term with sign
    assign term_temp = (s_bit[0] ? current_r : -current_r);
    assign term = term_temp + sum;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            counter <= 4'd0;
            sum <= 16'd0;
            r <= 8'd0;
            C <= 16'd0;
            D <= 16'd0;
            a_pow_n <= 16'd0;
            r_k <= 8'd0;
            current_r <= 8'd0;
            bit_pos <= 4'd0;
            base <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE_R;
                        counter <= 4'd0;
                        sum <= 16'd0;
                        current_r <= 8'd1;
                        bit_pos <= 4'd0;
                        r <= (b * 8'd255) / a;
                    end
                end

                COMPUTE_R: begin
                    if (counter == 4'd0) begin
                        r_k <= 8'd1;
                        base <= r;
                        counter <= k;
                    end else if (counter > 4'd0) begin
                        r_k <= (r_k * base) >> 8;
                        counter <= counter - 4'd1;
                    end

                    if (counter == 4'd1) begin
                        state <= COMPUTE_C;
                        counter <= 4'd0;
                        current_r <= 8'd1;
                        sum <= 16'd0;
                        bit_pos <= 4'd0;
                    end
                end

                COMPUTE_C: begin
                    if (bit_pos < k) begin
                        sum <= term[15:0];
                        current_r <= (current_r * r) >> 8;
                        bit_pos <= bit_pos + 4'd1;
                    end else begin
                        C <= sum;
                        state <= COMPUTE_D;
                        counter <= 4'd0;
                        sum <= 16'd0;
                        current_r <= 8'd1;
                    end
                end

                COMPUTE_D: begin
                    if (counter < k) begin
                        sum <= sum + current_r;
                        current_r <= (current_r * r_k) >> 8;
                        counter <= counter + 4'd1;
                    end else begin
                        D <= sum;
                        state <= COMPLETE;
                        a_pow_n <= a;
                    end
                end

                COMPLETE: begin
                    result <= (a_pow_n * C * D) >> 8;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule