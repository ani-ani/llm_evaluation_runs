module tuple_concatenator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] elem0,
    input wire [7:0] elem1,
    input wire [7:0] elem2,
    input wire [7:0] elem3,
    output reg [255:0] result,
    output reg [5:0] length,
    output reg done
);

    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CONCAT0   = 3'd1;
    localparam [2:0] ADD_DELIM0 = 3'd2;
    localparam [2:0] CONCAT1   = 3'd3;
    localparam [2:0] ADD_DELIM1 = 3'd4;
    localparam [2:0] CONCAT2   = 3'd5;
    localparam [2:0] ADD_DELIM2 = 3'd6;
    localparam [2:0] CONCAT3   = 3'd7;
    localparam [2:0] COMPLETE  = 3'd8;

    reg [2:0] current_state, next_state;
    reg [255:0] result_reg;
    reg [5:0] pos_reg;
    reg [5:0] len_reg;
    localparam [7:0] DELIM = 8'h2D;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result_reg <= 256'd0;
            pos_reg <= 6'd0;
            len_reg <= 6'd0;
            result <= 256'd0;
            length <= 6'd0;
            done <= 1'b0;
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    result_reg <= 256'd0;
                    pos_reg <= 6'd0;
                    len_reg <= 6'd0;
                    result <= 256'd0;
                    length <= 6'd0;
                    done <= 1'b0;
                end

                CONCAT0: begin
                    result_reg[7:0] <= elem0;
                    pos_reg <= 6'd1;
                    len_reg <= 6'd1;
                end

                ADD_DELIM0: begin
                    result_reg[15:8] <= DELIM;
                    pos_reg <= 6'd2;
                    len_reg <= 6'd2;
                end

                CONCAT1: begin
                    result_reg[23:16] <= elem1;
                    pos_reg <= 6'd3;
                    len_reg <= 6'd3;
                end

                ADD_DELIM1: begin
                    result_reg[31:24] <= DELIM;
                    pos_reg <= 6'd4;
                    len_reg <= 6'd4;
                end

                CONCAT2: begin
                    result_reg[39:32] <= elem2;
                    pos_reg <= 6'd5;
                    len_reg <= 6'd5;
                end

                ADD_DELIM2: begin
                    result_reg[47:40] <= DELIM;
                    pos_reg <= 6'd6;
                    len_reg <= 6'd6;
                end

                CONCAT3: begin
                    result_reg[55:48] <= elem3;
                    pos_reg <= 6'd7;
                    len_reg <= 6'd7;
                    result <= result_reg;
                    length <= len_reg;
                end

                COMPLETE: begin
                    done <= 1'b1;
                end

                default: begin
                    current_state <= IDLE;
                    result_reg <= 256'd0;
                    pos_reg <= 6'd0;
                    len_reg <= 6'd0;
                    result <= 256'd0;
                    length <= 6'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    always @(*) begin
        next_state = current_state;

        case (current_state)
            IDLE: begin
                if (start)
                    next_state = CONCAT0;
            end

            CONCAT0: next_state = ADD_DELIM0;
            ADD_DELIM0: next_state = CONCAT1;
            CONCAT1: next_state = ADD_DELIM1;
            ADD_DELIM1: next_state = CONCAT2;
            CONCAT2: next_state = ADD_DELIM2;
            ADD_DELIM2: next_state = CONCAT3;
            CONCAT3: next_state = COMPLETE;
            COMPLETE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule