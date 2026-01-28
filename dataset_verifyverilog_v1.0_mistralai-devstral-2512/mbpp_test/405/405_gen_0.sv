module check_tuple_element (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] search_value,
    input wire [7:0] tuple_data[0:15],
    input wire [4:0] tuple_len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] SEARCHING = 2'd1;
    localparam [1:0] DONE      = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [4:0] index;
    reg found;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 5'd0;
            found <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SEARCHING;
                        index <= 5'd0;
                        found <= 1'b0;
                    end
                end

                SEARCHING: begin
                    done <= 1'b0;
                    if (tuple_data[index] == search_value) begin
                        found <= 1'b1;
                    end
                    if (index == tuple_len - 1) begin
                        state <= DONE;
                        result <= found;
                    end else begin
                        index <= index + 5'd1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule