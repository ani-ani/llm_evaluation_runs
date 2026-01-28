module smoothie_transport(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] D_in,
    input wire [31:0] W_in,
    input wire [31:0] C_in,
    output reg [31:0] result_high,
    output reg [31:0] result_low,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC_LOOP = 2'd1;
    localparam [1:0] FINAL_CALC = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [63:0] fuel_rem;
    reg [63:0] dist_rem;
    reg [31:0] n;
    reg [63:0] step;
    reg [63:0] delivered;
    reg [31:0] loop_count;
    localparam [7:0] MAX_LOOP = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            fuel_rem <= 64'd0;
            dist_rem <= 64'd0;
            n <= 32'd0;
            step <= 64'd0;
            delivered <= 64'd0;
            loop_count <= 8'd0;
            result_high <= 32'd0;
            result_low <= 32'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    loop_count <= 8'd0;
                    if (start) begin
                        // Initialize with scaled inputs (treat as integers)
                        fuel_rem <= {32'd0, W_in};
                        dist_rem <= {32'd0, D_in};
                        if (W_in <= C_in) begin
                            // Simple case: W <= C
                            if (W_in > D_in) begin
                                delivered <= {32'd0, W_in - D_in};
                            end else begin
                                delivered <= 64'd0;
                            end
                            state <= FINAL_CALC;
                        end else begin
                            state <= CALC_LOOP;
                        end
                    end
                end

                CALC_LOOP: begin
                    loop_count <= loop_count + 8'd1;
                    if (loop_count >= MAX_LOOP) begin
                        // Safety: prevent infinite loops
                        state <= FINAL_CALC;
                    end else begin
                        // Calculate n = ceil(fuel_rem / C)
                        if (fuel_rem[63:32] == 32'd0 && fuel_rem[31:0] <= C_in) begin
                            n <= 32'd1;
                        end else begin
                            n <= (fuel_rem + {32'd0, C_in} - 1'b1) / {32'd0, C_in};
                        end

                        // step = C / (2*n - 1)
                        if (n == 32'd1) begin
                            step <= {32'd0, C_in};
                        end else begin
                            step <= {32'd0, C_in} / (2'd1 * n - 32'd1);
                        end

                        // Check if step >= dist_rem
                        if (step >= dist_rem) begin
                            // Reach destination
                            delivered <= fuel_rem - dist_rem * (2'd1 * n - 32'd1);
                            state <= FINAL_CALC;
                        end else begin
                            // Advance by step
                            dist_rem <= dist_rem - step;
                            fuel_rem <= fuel_rem - {32'd0, C_in};
                            // Check if fuel_rem <= C
                            if (fuel_rem[63:32] == 32'd0 && fuel_rem[31:0] <= C_in) begin
                                state <= FINAL_CALC;
                            end
                        end
                    end
                end

                FINAL_CALC: begin
                    if (fuel_rem > 64'd0 && dist_rem > 64'd0) begin
                        // Final segment: fuel_rem <= C
                        if (fuel_rem > dist_rem) begin
                            delivered <= fuel_rem - dist_rem;
                        end else begin
                            delivered <= 64'd0;
                        end
                    end
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    // Output result as 64-bit integer (high and low 32 bits)
                    result_high <= delivered[63:32];
                    result_low <= delivered[31:0];
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule