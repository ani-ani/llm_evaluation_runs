module color_path_max(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n_in,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] CHECK_N = 3'd1;
    localparam [2:0] FIND_D  = 3'd2;
    localparam [2:0] CHECK_POWER = 3'd3;
    localparam [2:0] FINISH  = 3'd4;

    reg [2:0] state, next_state;
    reg [15:0] n_reg, d_reg, temp_reg;
    reg [7:0] d_counter;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            n_reg <= 16'd0;
            d_reg <= 16'd0;
            temp_reg <= 16'd0;
            d_counter <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    n_reg = n_in;
                    next_state = CHECK_N;
                end
            end

            CHECK_N: begin
                if (n_reg == 16'd1) begin
                    result = 16'd1;
                    next_state = FINISH;
                end else begin
                    d_counter = 8'd2;
                    next_state = FIND_D;
                end
            end

            FIND_D: begin
                if (d_counter > 8'd256) begin
                    result = n_reg;
                    next_state = FINISH;
                end else if (n_reg % d_counter == 16'd0) begin
                    d_reg = d_counter;
                    temp_reg = n_reg;
                    next_state = CHECK_POWER;
                end else begin
                    d_counter = d_counter + 8'd1;
                end
            end

            CHECK_POWER: begin
                if (temp_reg == 16'd1) begin
                    result = d_reg;
                    next_state = FINISH;
                end else if (temp_reg % d_reg == 16'd0) begin
                    temp_reg = temp_reg / d_reg;
                end else begin
                    d_counter = d_counter + 8'd1;
                    next_state = FIND_D;
                end
            end

            FINISH: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule