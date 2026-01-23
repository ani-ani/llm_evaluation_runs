module digit_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    output reg [4:0] addr_out,
    output reg [4:0] count,
    output reg done
);

    // State Encoding
    localparam IDLE      = 3'b000;
    localparam READ_CHAR = 3'b001;
    localparam CHECK     = 3'b010;
    localparam UPDATE    = 3'b011;
    localparam FINISH    = 3'b100;

    // Internal Registers
    reg [2:0] current_state, next_state;
    reg [3:0] index_reg;    // Counts from 0 to 15
    reg [4:0] count_reg;
    reg done_reg;

    // Sequential Logic (State & Data Registers)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            index_reg <= 4'd0;
            count_reg <= 5'd0;
            done_reg <= 1'b0;
        end else begin
            current_state <= next_state;
            
            // Data update logic based on state
            case (current_state)
                IDLE: begin
                    if (start) begin
                        index_reg <= 4'd0;
                        count_reg <= 5'd0;
                        done_reg <= 1'b0;
                    end
                end
                UPDATE: begin
                    if (char_in >= 8'h30 && char_in <= 8'h39) begin
                        count_reg <= count_reg + 1'b1;
                    end
                    index_reg <= index_reg + 1'b1;
                end
                FINISH: begin
                    done_reg <= 1'b1;
                end
            endcase
        end
    end

    // Combinational Logic (Next State Decoder)
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = READ_CHAR;
                else
                    next_state = IDLE;
            end
            READ_CHAR: begin
                // Memory read latency assumed 1 cycle
                next_state = CHECK;
            end
            CHECK: begin
                next_state = UPDATE;
            end
            UPDATE: begin
                if (index_reg == 4'd15) // Just processed the 16th char (index 15)
                    next_state = FINISH;
                else
                    next_state = READ_CHAR;
            end
            FINISH: begin
                // Hold state until reset or new start (implicit)
                next_state = FINISH;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output Logic
    always @(*) begin
        // Default outputs
        addr_out = 5'd0;
        count = count_reg;
        done = done_reg;

        case (current_state)
            READ_CHAR: begin
                // Output current address for read
                addr_out = {1'b0, index_reg};
            end
            default: begin
                addr_out = 5'd0;
            end
        endcase
    end

endmodule