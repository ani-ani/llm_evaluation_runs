module profit_calculator (
    input clk,
    input rst_n,
    input start,
    input [31:0] profit_cents,      // Total profit in cents
    input [15:0] pita_profit_cents, // Profit per pita in cents
    input [15:0] pizza_profit_cents, // Profit per pizza in cents
    output reg [15:0] pitas,
    output reg [15:0] pizzas,
    output reg valid,
    output reg done
);

// Parameters for maximum values
parameter MAX_ITERATIONS = 1000;
parameter MAX_SOLUTIONS = 16;

// State machine states
parameter IDLE = 3'b000;
parameter COMPUTE = 3'b001;
parameter CHECK = 3'b010;
parameter OUTPUT = 3'b011;
parameter INCREMENT = 3'b100;
parameter FINISHED = 3'b101;

// Internal registers
reg [2:0] state;
reg [15:0] x;           // Current pita count
reg [15:0] y;           // Current pizza count  
reg [31:0] remainder;   // Remaining profit after x*pita
reg [7:0] solution_count;
reg [31:0] product;     // x * pita_profit

// Combinational calculations
wire [31:0] product_wire = x * pita_profit_cents;
wire [31:0] remainder_wire = profit_cents - product_wire;
wire [31:0] y_calc = remainder_wire / pizza_profit_cents;
wire [31:0] check = y_calc * pizza_profit_cents;
wire valid_solution = (product_wire <= profit_cents) && 
                      (remainder_wire >= 0) && 
                      (check == remainder_wire) &&
                      (y_calc <= 16'hFFFF);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        pitas <= 0;
        pizzas <= 0;
        valid <= 0;
        done <= 0;
        x <= 0;
        y <= 0;
        solution_count <= 0;
    end else begin
        case (state)
            IDLE: begin
                valid <= 0;
                done <= 0;
                if (start) begin
                    x <= 0;
                    y <= 0;
                    solution_count <= 0;
                    state <= COMPUTE;
                end
            end
            
            COMPUTE: begin
                product <= product_wire;
                state <= CHECK;
            end
            
            CHECK: begin
                if (x > MAX_ITERATIONS || solution_count >= MAX_SOLUTIONS) begin
                    state <= FINISHED;
                end else if (valid_solution) begin
                    pitas <= x;
                    pizzas <= y_calc;
                    state <= OUTPUT;
                end else begin
                    state <= INCREMENT;
                end
            end
            
            OUTPUT: begin
                valid <= 1;
                solution_count <= solution_count + 1;
                state <= INCREMENT;
            end
            
            INCREMENT: begin
                valid <= 0;
                x <= x + 1;
                state <= COMPUTE;
            end
            
            FINISHED: begin
                done <= 1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule