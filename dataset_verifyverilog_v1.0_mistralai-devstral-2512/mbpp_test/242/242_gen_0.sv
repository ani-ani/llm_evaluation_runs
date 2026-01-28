module char_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str [0:15],
    input wire [3:0] len,
    output reg [4:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] COUNTING = 2'd1;
    localparam [1:0] DONE     = 2'd2;

    reg [1:0] state;
    reg [3:0] index;
    reg [4:0] count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            count <= 5'd0;
            result <= 5'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (len == 4'd0) begin
                            state <= DONE;
                        end else begin
                            state <= COUNTING;
                            index <= 4'd0;
                            count <= 5'd0;
                        end
                    end
                end

                COUNTING: begin
                    if (index < len) begin
                        count <= count + 5'd1;
                        index <= index + 4'd1;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    result <= count;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule