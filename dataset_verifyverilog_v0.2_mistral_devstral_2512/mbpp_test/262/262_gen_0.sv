module array_splitter (
    input clk,
    input rst_n,
    input start,
    input [SIZE-1:0][WIDTH-1:0] data_in,
    input [4:0] L,
    output reg [SIZE-1:0][WIDTH-1:0] part1,
    output reg [SIZE-1:0][WIDTH-1:0] part2,
    output reg done
);

parameter SIZE = 16;
parameter WIDTH = 8;

// State definitions
typedef enum logic [1:0] {
    IDLE,
    LOAD,
    PROCESS,
    DONE
} state_t;

state_t current_state, next_state;

// Internal buffer to store input data
reg [SIZE-1:0][WIDTH-1:0] data_buffer;

// Counter for processing
reg [3:0] counter;

// State machine logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
        done <= 0;
        counter <= 0;
        part1 <= '0;
        part2 <= '0;
    end else begin
        current_state <= next_state;
    end
end

// Next state logic
always @(*) begin
    next_state = current_state;
    case (current_state)
        IDLE: begin
            if (start) next_state = LOAD;
        end
        LOAD: begin
            next_state = PROCESS;
        end
        PROCESS: begin
            if (counter == 15) next_state = DONE;
        end
        DONE: begin
            if (!start) next_state = IDLE;
        end
        default: next_state = IDLE;
    endcase
end

// Data processing logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_buffer <= '0;
        counter <= 0;
        done <= 0;
    end else begin
        case (current_state)
            LOAD: begin
                data_buffer <= data_in;
                counter <= 0;
                done <= 0;
            end
            PROCESS: begin
                // Unrolled logic for processing
                if (counter < SIZE) begin
                    // Initialize part1 and part2
                    if (counter == 0) begin
                        part1 <= '0;
                        part2 <= '0;
                    end
                    // Fill part1 with valid elements (0 to L-1)
                    if (counter < L) begin
                        part1[counter] <= data_buffer[counter];
                    end
                    // Fill part2 with valid elements (L to SIZE-1)
                    if (counter >= L) begin
                        part2[counter - L] <= data_buffer[counter];
                    end
                    counter <= counter + 1;
                end
            end
            DONE: begin
                done <= 1;
            end
            default: ;
        endcase
    end
end

endmodule