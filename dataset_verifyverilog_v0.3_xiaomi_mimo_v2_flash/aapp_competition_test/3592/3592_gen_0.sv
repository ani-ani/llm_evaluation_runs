module profit_calculator (
    input clk,
    input rst_n,
    input start,
    input [31:0] profit_cents,
    input [15:0] pita_profit_cents,
    input [15:0] pizza_profit_cents,
    output reg [15:0] pitas,
    output reg [15:0] pizzas,
    output reg valid,
    output reg done
);

localparam [2:0] IDLE = 3'd0;
localparam [2:0] COMPUTE = 3'd1;
localparam [2:0] CHECK = 3'd2;
localparam [2:0] OUTPUT = 3'd3;
localparam [2:0] INCREMENT = 3'd4;
localparam [2:0] FINISHED = 3'd5;

localparam [15:0] MAX_ITERATIONS = 16'd1000;
localparam [7:0] MAX_SOLUTIONS = 8'd16;

reg [2:0] state;
reg [15:0] x;
reg [7:0] solution_count;
reg [31:0] product_reg;
reg [31:0] remainder_reg;
reg [15:0] y_reg;

wire [31:0] product_wire;
wire [31:0] remainder_wire;
wire [15:0] y_calc_wire;
wire [31:0] check_wire;
wire valid_solution;

assign product_wire = x * pita_profit_cents;
assign remainder_wire = profit_cents - product_wire;
assign y_calc_wire = remainder_wire / pizza_profit_cents;
assign check_wire = y_calc_wire * pizza_profit_cents;
assign valid_solution = (product_wire <= profit_cents) && 
                        (remainder_wire <= profit_cents) && 
                        (check_wire == remainder_wire) &&
                        (y_calc_wire <= 16'hFFFF);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        pitas <= 16'd0;
        pizzas <= 16'd0;
        valid <= 1'b0;
        done <= 1'b0;
        x <= 16'd0;
        solution_count <= 8'd0;
        product_reg <= 32'd0;
        remainder_reg <= 32'd0;
        y_reg <= 16'd0;
    end else begin
        case (state)
            IDLE: begin
                valid <= 1'b0;
                done <= 1'b0;
                if (start) begin
                    x <= 16'd0;
                    solution_count <= 8'd0;
                    state <= COMPUTE;
                end
            end
            
            COMPUTE: begin
                product_reg <= product_wire;
                remainder_reg <= remainder_wire;
                y_reg <= y_calc_wire;
                state <= CHECK;
            end
            
            CHECK: begin
                if (x > MAX_ITERATIONS || solution_count >= MAX_SOLUTIONS) begin
                    state <= FINISHED;
                end else if (valid_solution) begin
                    pitas <= x;
                    pizzas <= y_reg;
                    state <= OUTPUT;
                end else begin
                    state <= INCREMENT;
                end
            end
            
            OUTPUT: begin
                valid <= 1'b1;
                solution_count <= solution_count + 8'd1;
                state <= INCREMENT;
            end
            
            INCREMENT: begin
                valid <= 1'b0;
                x <= x + 16'd1;
                state <= COMPUTE;
            end
            
            FINISHED: begin
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule