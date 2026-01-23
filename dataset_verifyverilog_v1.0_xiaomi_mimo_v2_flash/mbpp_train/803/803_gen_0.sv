module perfect_square_checker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [7:0] i;
    reg [7:0] i_reg;
    reg [7:0] n_reg;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15;

    // Combinational signals
    wire [15:0] i_squared;
    wire [7:0] n_div_i;
    wire [7:0] n_mod_i;
    wire i_squared_le_n;
    wire i_squared_gt_n;
    wire is_perfect_square;

    // Combinational calculations
    assign i_squared = i_reg * i_reg;
    assign n_div_i = n_reg / i_reg;
    assign n_mod_i = n_reg % i_reg;
    assign i_squared_le_n = (i_squared <= {8'd0, n_reg});
    assign i_squared_gt_n = (i_squared > {8'd0, n_reg});
    assign is_perfect_square = (n_mod_i == 8'd0) && (n_div_i == i_reg);

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK;
                end else begin
                    next_state = IDLE;
                end
            end
            CHECK: begin
                if (i_squared_gt_n || cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end else if (is_perfect_square) begin
                    next_state = FINISH;
                end else begin
                    next_state = CHECK;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output and internal register logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 1'b0;
            done <= 1'b0;
            i <= 8'd0;
            i_reg <= 8'd0;
            n_reg <= 8'd0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        i <= 8'd1;
                        i_reg <= 8'd1;
                        n_reg <= n;
                        cycle_count <= 4'd0;
                        result <= 1'b0;
                    end
                end
                CHECK: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (is_perfect_square) begin
                        result <= 1'b1;
                    end else if (i_squared_gt_n || cycle_count >= MAX_CYCLES) begin
                        result <= 1'b0;
                    end else begin
                        i <= i + 8'd1;
                        i_reg <= i_reg + 8'd1;
                    end
                end
                FINISH: begin
                    done <= 1'b1;
                end
                default: begin
                    result <= 1'b0;
                    done <= 1'b0;
                    i <= 8'd0;
                    i_reg <= 8'd0;
                    n_reg <= 8'd0;
                    cycle_count <= 4'd0;
                end
            endcase
        end
    end

endmodule