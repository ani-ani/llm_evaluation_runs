module count_equal_numbers (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] x,
    input wire signed [7:0] y,
    input wire signed [7:0] z,
    output reg [1:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SAMPLE = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    reg [1:0] state;
    reg signed [7:0] x_reg, y_reg, z_reg;
    wire xy_equal, yz_equal, xz_equal;
    wire [1:0] count_result;

    // Registered outputs
    reg done_reg;
    reg [1:0] result_reg;

    // Combinational comparators
    assign xy_equal = (x_reg == y_reg);
    assign yz_equal = (y_reg == z_reg);
    assign xz_equal = (x_reg == z_reg);

    // Combinational result logic
    assign count_result = (xy_equal && yz_equal && xz_equal) ? 2'd3 :
                          ((xy_equal ^ yz_equal ^ xz_equal) && (xy_equal || yz_equal || xz_equal)) ? 2'd2 :
                          2'd0;

    // State machine and registered outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_reg <= 2'd0;
            done_reg <= 1'b0;
            x_reg <= 8'sd0;
            y_reg <= 8'sd0;
            z_reg <= 8'sd0;
        end else begin
            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    result_reg <= 2'd0;
                    if (start) begin
                        state <= SAMPLE;
                    end
                end

                SAMPLE: begin
                    x_reg <= x;
                    y_reg <= y;
                    z_reg <= z;
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    result_reg <= count_result;
                    state <= FINISH;
                end

                FINISH: begin
                    done_reg <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Output assignments
    always @(*) begin
        result = result_reg;
        done = done_reg;
    end

endmodule