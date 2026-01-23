module perfect_squares(
    input clk,
    input rst_n,
    input start,
    input [7:0] a,
    input [7:0] b,
    output reg [7:0] result,
    output reg [3:0] count,
    output reg done,
    output reg valid
);

    // Internal registers
    reg [7:0] current_num;
    reg [7:0] current_base;
    reg [7:0] square_reg;
    reg [2:0] state;
    reg [3:0] store_idx;
    reg [2:0] output_idx;
    
    // Storage for up to 8 perfect squares
    reg [7:0] stored_squares [0:7];
    
    // State encoding
    localparam IDLE = 3'b000;
    localparam CHECK_NUMBER = 3'b001;
    localparam FIND_SQUARE = 3'b010;
    localparam STORE_RESULT = 3'b011;
    localparam OUTPUT_RESULTS = 3'b100;
    localparam DONE_STATE = 3'b101;
    
    // Combinational logic for square calculation
    wire [7:0] next_square;
    assign next_square = current_base * current_base;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'b0;
            count <= 4'b0;
            done <= 1'b0;
            valid <= 1'b0;
            current_num <= 8'b0;
            current_base <= 8'b0;
            square_reg <= 8'b0;
            store_idx <= 4'b0;
            output_idx <= 3'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        current_num <= a;
                        current_base <= 8'd1;
                        store_idx <= 4'b0;
                        count <= 4'b0;
                        output_idx <= 3'b0;
                        state <= CHECK_NUMBER;
                    end
                end
                
                CHECK_NUMBER: begin
                    if (current_num > b) begin
                        state <= OUTPUT_RESULTS;
                        valid <= 1'b0;
                    end else begin
                        current_base <= 8'd1;
                        state <= FIND_SQUARE;
                    end
                end
                
                FIND_SQUARE: begin
                    square_reg <= next_square;
                    if (next_square == current_num) begin
                        state <= STORE_RESULT;
                    end else if (current_base >= 8'd15 || next_square > current_num) begin
                        // Not a perfect square, move to next number
                        current_num <= current_num + 8'd1;
                        state <= CHECK_NUMBER;
                    end else begin
                        current_base <= current_base + 8'd1;
                    end
                end
                
                STORE_RESULT: begin
                    if (store_idx < 4'd8) begin
                        stored_squares[store_idx] <= current_num;
                        store_idx <= store_idx + 4'd1;
                        count <= count + 4'd1;
                    end
                    current_num <= current_num + 8'd1;
                    state <= CHECK_NUMBER;
                end
                
                OUTPUT_RESULTS: begin
                    if (output_idx < store_idx[2:0]) begin
                        result <= stored_squares[output_idx];
                        valid <= 1'b1;
                        output_idx <= output_idx + 3'd1;
                    end else begin
                        valid <= 1'b0;
                        done <= 1'b1;
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    valid <= 1'b0;
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule