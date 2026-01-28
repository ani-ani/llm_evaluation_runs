module BetweenPlanets(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] p1,
    input wire [2:0] p2,
    output reg [63:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [3:0] write_ptr;
    reg [2:0] low;
    reg [2:0] high;
    reg [3:0] i;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd20;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 64'd0;
            done <= 1'b0;
            write_ptr <= 4'd0;
            cycle_count <= 4'd0;
            i <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        // Validate inputs
                        if (p1 == p2 || p1 > 7 || p2 > 7) begin
                            result <= 64'hFFFFFFFFFFFFFFFF;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            low = (p1 < p2) ? p1 : p2;
                            high = (p2 < p1) ? p2 : p1;
                            write_ptr <= 4'd0;
                            i <= 4'd0;
                            state <= COMPUTE;
                        end
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (i < 8) begin
                        if (i > low && i < high) begin
                            result[(write_ptr * 8) +: 8] <= i;
                            write_ptr <= write_ptr + 4'd1;
                        end
                        i <= i + 4'd1;
                        if (i == 8) begin
                            if (write_ptr == 0) begin
                                result <= 64'hFFFFFFFFFFFFFFFF;
                            end
                            state <= FINISH;
                        end
                    end else begin
                        state <= FINISH;
                    end
                    if (cycle_count >= MAX_CYCLES) begin
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