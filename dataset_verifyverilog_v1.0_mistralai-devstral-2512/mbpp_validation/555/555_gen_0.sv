module sum_cubes_diff(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPUTE_S = 3'd1;
    localparam [2:0] COMPUTE_RESULT = 3'd2;
    localparam [2:0] FINISH  = 3'd3;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd64;

    reg [31:0] S;
    reg [31:0] temp_result;
    reg [7:0] n_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            S <= 32'd0;
            temp_result <= 32'd0;
            n_reg <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        n_reg <= n;
                        state <= COMPUTE_S;
                    end
                end

                COMPUTE_S: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute S = N * (N + 1) / 2
                    S <= (n_reg * (n_reg + 8'd1)) >>> 1;
                    state <= COMPUTE_RESULT;
                end

                COMPUTE_RESULT: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute result = S * (S - 1)
                    temp_result <= S * (S - 32'd1);
                    
                    // Clamp to 32-bit max if overflow
                    if (temp_result[31] && (n_reg > 8'd128)) begin
                        result <= 32'hFFFFFFFF;
                    end else begin
                        result <= temp_result;
                    end
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule