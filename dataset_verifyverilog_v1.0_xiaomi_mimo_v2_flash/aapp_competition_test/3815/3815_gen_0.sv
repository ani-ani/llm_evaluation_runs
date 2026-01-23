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

// Parameters
parameter MOD = 256;
parameter MAX_CYCLES = 8'd100;

// State machine states
localparam [2:0] IDLE = 3'd0;
localparam [2:0] COMPUTE_R = 3'd1;
localparam [2:0] COMPUTE_C = 3'd2;
localparam [2:0] COMPUTE_D = 3'd3;
localparam [2:0] COMPUTE_RESULT = 3'd4;
localparam [2:0] COMPLETE = 3'd5;

// Internal registers
reg [2:0] state;
reg [2:0] next_state;
reg [3:0] counter;
reg [15:0] sum;
reg [7:0] r;
reg [15:0] C;
reg [15:0] D;
reg [15:0] a_pow_n;
reg [7:0] r_k;
reg [7:0] current_r;
reg [7:0] base;
reg [3:0] bit_pos;
reg [7:0] cycle_count;

// Combinational logic
wire [15:0] r_temp;
wire [15:0] term_temp;
wire [15:0] mult_temp1;
wire [15:0] mult_temp2;

// Computation for r = (b * 255 / a) >> 8
wire [15:0] r_mult = b * 8'hFF;
assign r_temp = r_mult / a;

// Term computation with sign
wire s_bit = s_sequence[bit_pos];
assign term_temp = (s_bit ? current_r : (16'h0000 - current_r));

// Multiplication for result: a^n * C * D with proper shifting
wire [15:0] mult1 = (a_pow_n * C) >> 8;
assign mult_temp1 = mult1 * D;
assign mult_temp2 = mult_temp1 >> 8;

// State transition logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 16'd0;
        counter <= 4'd0;
        sum <= 16'd0;
        current_r <= 8'd0;
        bit_pos <= 4'd0;
        r <= 8'd0;
        r_k <= 8'd0;
        base <= 8'd0;
        C <= 16'd0;
        D <= 16'd0;
        a_pow_n <= 16'd0;
        cycle_count <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_count <= 8'd0;
                if (start) begin
                    state <= COMPUTE_R;
                    counter <= 4'd0;
                    sum <= 16'd0;
                    current_r <= 8'h01;
                    bit_pos <= 4'd0;
                    // Compute initial r
                    r <= r_temp[7:0];
                end
            end

            COMPUTE_R: begin
                cycle_count <= cycle_count + 8'd1;
                if (counter == 4'd0) begin
                    r_k <= 8'h01;
                    base <= r;
                    counter <= k;
                end else if (counter > 4'd0) begin
                    r_k <= (r_k * base) >> 8;
                    counter <= counter - 4'd1;
                end

                if (counter == 4'd1 && k > 4'd0) begin
                    state <= COMPUTE_C;
                    counter <= 4'd0;
                    current_r <= 8'h01;
                    sum <= 16'd0;
                    bit_pos <= 4'd0;
                end else if (counter == 4'd0 && k == 4'd0) begin
                    // k=0 case, skip to complete
                    state <= COMPLETE;
                end else if (cycle_count >= MAX_CYCLES) begin
                    state <= COMPLETE;
                end
            end

            COMPUTE_C: begin
                cycle_count <= cycle_count + 8'd1;
                if (bit_pos < k) begin
                    // Add signed term to sum
                    if (s_bit) begin
                        sum <= sum + current_r;
                    end else begin
                        sum <= sum - current_r;
                    end
                    // Update current_r for next iteration
                    current_r <= (current_r * r) >> 8;
                    bit_pos <= bit_pos + 4'd1;
                end else begin
                    C <= sum;
                    state <= COMPUTE_D;
                    counter <= 4'd0;
                    sum <= 16'd0;
                    current_r <= 8'h01;
                end
                if (cycle_count >= MAX_CYCLES) begin
                    state <= COMPLETE;
                end
            end

            COMPUTE_D: begin
                cycle_count <= cycle_count + 8'd1;
                // Compute D = sum of geometric series with ratio r_k
                if (counter < k && k > 4'd0) begin
                    sum <= sum + current_r;
                    current_r <= (current_r * r_k) >> 8;
                    counter <= counter + 4'd1;
                end else begin
                    D <= sum;
                    state <= COMPUTE_RESULT;
                    // Compute a^n in Q8.8
                    a_pow_n <= a;
                end
                if (cycle_count >= MAX_CYCLES) begin
                    state <= COMPLETE;
                end
            end

            COMPUTE_RESULT: begin
                cycle_count <= cycle_count + 8'd1;
                // result = a^n * C * D
                result <= mult_temp2;
                state <= COMPLETE;
            end

            COMPLETE: begin
                done <= 1'b1;
                state <= IDLE;
            end

            default: begin
                state <= IDLE;
                done <= 1'b0;
            end
        endcase
    end
end

endmodule