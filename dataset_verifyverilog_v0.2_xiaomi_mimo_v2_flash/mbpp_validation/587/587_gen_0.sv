module list_to_tuple (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_elements,
    input [7:0] list_in [0:7],
    output reg [7:0] tuple_out [0:7],
    output reg done,
    output reg valid
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE_STATE = 2'b10;

    reg [1:0] current_state, next_state;
    reg [2:0] index;
    reg [2:0] count;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = PROCESSING;
                else
                    next_state = IDLE;
            end
            PROCESSING: begin
                if (index < num_elements) // Still copying elements
                    next_state = PROCESSING;
                else
                    next_state = DONE_STATE;
            end
            DONE_STATE: begin
                if (start)
                    next_state = PROCESSING;
                else
                    next_state = DONE_STATE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output logic and datapath
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                tuple_out[i] <= 8'b0;
            end
            done <= 1'b0;
            valid <= 1'b0;
            index <= 3'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    index <= 3'b0;
                end
                PROCESSING: begin
                    if (index < num_elements) begin
                        tuple_out[index] <= list_in[index];
                        index <= index + 1'b1;
                    end
                    done <= 1'b0;
                    valid <= 1'b0;
                end
                DONE_STATE: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                end
            endcase
        end
    end

endmodule