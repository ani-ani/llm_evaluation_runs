module sequential_search(
    input clk,
    input rst_n,
    input start,
    input [7:0] search_item,
    input [63:0] array_flat,
    output reg found,
    output reg [2:0] index,
    output reg done
);

// State definitions
localparam IDLE = 2'b00;
localparam CHECKING = 2'b01;
localparam COMPLETE = 2'b10;

reg [1:0] state;
reg [2:0] counter;
reg [7:0] current_element;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        found <= 1'b0;
        index <= 3'b000;
        done <= 1'b0;
        counter <= 3'b000;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                counter <= 3'b000;
                if (start) begin
                    state <= CHECKING;
                    current_element <= array_flat[63:56];
                end
            end
            
            CHECKING: begin
                if (current_element == search_item) begin
                    found <= 1'b1;
                    index <= counter;
                    done <= 1'b1;
                    state <= COMPLETE;
                end else if (counter == 3'b111) begin
                    found <= 1'b0;
                    index <= 3'b111;
                    done <= 1'b1;
                    state <= COMPLETE;
                end else begin
                    counter <= counter + 1'b1;
                    case (counter)
                        3'b000: current_element <= array_flat[55:48];
                        3'b001: current_element <= array_flat[47:40];
                        3'b010: current_element <= array_flat[39:32];
                        3'b011: current_element <= array_flat[31:24];
                        3'b100: current_element <= array_flat[23:16];
                        3'b101: current_element <= array_flat[15:8];
                        3'b110: current_element <= array_flat[7:0];
                        default: current_element <= array_flat[7:0];
                    endcase
                end
            end
            
            COMPLETE: begin
                if (!start) begin
                    state <= IDLE;
                    done <= 1'b0;
                    found <= 1'b0;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule