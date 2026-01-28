module equal_counter(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] x,
    input signed [7:0] y,
    input signed [7:0] z,
    output reg [1:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] OUTPUT  = 2'd2;

    reg [1:0] state;
    reg [1:0] next_state;
    reg signed [7:0] x_reg;
    reg signed [7:0] y_reg;
    reg signed [7:0] z_reg;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESS;
                else
                    next_state = IDLE;
            end
            PROCESS: next_state = OUTPUT;
            OUTPUT: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 2'd0;
            done <= 1'b0;
            x_reg <= 8'd0;
            y_reg <= 8'd0;
            z_reg <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // Input sampling
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_reg <= 8'd0;
            y_reg <= 8'd0;
            z_reg <= 8'd0;
        end else if (state == IDLE && start) begin
            x_reg <= x;
            y_reg <= y;
            z_reg <= z;
        end
    end

    // Result computation
    always @(*) begin
        reg xy_equal = (x_reg == y_reg);
        reg yz_equal = (y_reg == z_reg);
        reg xz_equal = (x_reg == z_reg);
        
        if (xy_equal && yz_equal && xz_equal) begin
            result = 2'd3;
        end else if (xy_equal || yz_equal || xz_equal) begin
            result = 2'd2;
        end else begin
            result = 2'd0;
        end
    end

    // Done signal generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            done <= (state == OUTPUT);
        end
    end

endmodule