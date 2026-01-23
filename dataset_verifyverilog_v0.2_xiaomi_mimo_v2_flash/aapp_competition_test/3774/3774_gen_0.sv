module max_chessmen(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] m,
    output reg [31:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam SWAP = 2'b01;
    localparam CALCULATE = 2'b10;
    localparam DONE_STATE = 2'b11;

    reg [1:0] current_state, next_state;
    reg [3:0] n_reg, m_reg; // Registers to hold swapped dimensions
    reg [31:0] next_result;
    reg next_done;

    // Intermediate combinational logic for calculation
    wire [3:0] n_swap, m_swap;
    wire [7:0] product;
    wire is_odd;
    
    // N=1 specific wires
    wire [3:0] r;
    wire [31:0] res_n1;
    
    // N=2 specific wires
    wire [31:0] res_n2;

    // Helper logic for swapping
    assign n_swap = (n <= m) ? n : m;
    assign m_swap = (n <= m) ? m : n;

    // Helper logic for N>=3
    assign product = n_reg * m_reg;
    assign is_odd = product[0];

    // N=1 Logic
    assign r = m_reg % 6;
    always @(*) begin
        if (r == 0)
            res_n1 = m_reg;
        else if (r <= 3)
            res_n1 = m_reg - r;
        else
            res_n1 = m_reg - (6 - r);
    end

    // N=2 Logic
    always @(*) begin
        if (m_reg == 2)
            res_n2 = 0;
        else if (m_reg == 3)
            res_n2 = 4;
        else if (m_reg == 7)
            res_n2 = 12;
        else
            res_n2 = n_reg * m_reg;
    end

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
            result <= next_result;
            done <= next_done;
        end
    end

    // Next State Logic & Output Logic
    always @(*) begin
        // Default assignments
        next_state = current_state;
        next_result = result;
        next_done = done;
        n_reg = n_reg;
        m_reg = m_reg;

        case (current_state)
            IDLE: begin
                next_done = 1'b0;
                if (start) begin
                    next_state = SWAP;
                end else begin
                    next_state = IDLE;
                end
            end

            SWAP: begin
                // Store swapped dimensions
                n_reg = n_swap;
                m_reg = m_swap;
                next_state = CALCULATE;
            end

            CALCULATE: begin
                // Perform calculation based on n_reg
                if (n_reg == 1) begin
                    next_result = res_n1;
                end else if (n_reg == 2) begin
                    next_result = res_n2;
                end else begin
                    // n >= 3
                    if (is_odd)
                        next_result = product - 1;
                    else
                        next_result = product;
                end
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                next_done = 1'b1;
                // Wait for start to go low to return to IDLE, or stay here
                if (!start) begin
                    next_state = IDLE;
                    next_done = 1'b0;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule