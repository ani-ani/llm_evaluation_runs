module circle_dance_solver (input clk, input rst_n, input start_load, input [2:0] addr, input [2:0] p_in, input write_en, output reg [7:0] solution_mask, output reg valid, output reg done);

// Internal registers
reg [2:0] p_mem [0:7];
reg [7:0] written_flags;
reg [3:0] write_count;
localparam NUM_WIZARDS = 8;

// State machine
typedef enum {IDLE, CHECKING, DONE} state_t;
state_t state;
reg [1:0] state_reg; // 2 bits

// For solution and counters
reg [7:0] mask_counter;
reg [7:0] solution;

// Output assignments
output reg [7:0] solution_mask;
output reg valid;
output reg done;

// Declare destination wires
wire [2:0] dest0, dest1, dest2, dest3, dest4, dest5, dest6, dest7;
wire collision;

// Assign outputs
assign solution_mask = solution;
assign valid = (state_reg == DONE) && (solution != 8'b0);
assign done = (state_reg == DONE);

// State machine and control logic
always @(posedge clk) begin
    if (!rst_n) begin
        state_reg <= IDLE;
        mask_counter <= 0;
        solution <= 8'b0;
        valid <= 0;
        done <= 0;
        p_mem <= 8'b0;
        written_flags <= 8'b0;
        write_count <= 0;
    end else begin
        case (state_reg)
            IDLE: begin
                if (write_count == NUM_WIZARDS) begin
                    state_reg <= CHECKING;
                    mask_counter <= 0;
                end
            end
            CHECKING: begin
                if (mask_counter < 256) begin
                    // Compute destinations for each wizard
                    dest0 = (mask_counter[0] == 0) ? ((0 - p_mem[0] + 8) & 7) : ((0 + p_mem[0]) & 7);
                    dest1 = (mask_counter[1] == 0) ? ((1 - p_mem[1] + 8) & 7) : ((1 + p_mem[1]) & 7);
                    dest2 = (mask_counter[2] == 0) ? ((2 - p_mem[2] + 8) & 7) : ((2 + p_mem[2]) & 7);
                    dest3 = (mask_counter[3] == 0) ? ((3 - p_mem[3] + 8) & 7) : ((3 + p_mem[3]) & 7);
                    dest4 = (mask_counter[4] == 0) ? ((4 - p_mem[4] + 8) & 7) : ((4 + p_mem[4]) & 7);
                    dest5 = (mask_counter[5] == 0) ? ((5 - p_mem[5] + 8) & 7) : ((5 + p_mem[5]) & 7);
                    dest6 = (mask_counter[6] == 0) ? ((6 - p_mem[6] + 8) & 7) : ((6 + p_mem[6]) & 7);
                    dest7 = (mask_counter[7] == 0) ? ((7 - p_mem[7] + 8) & 7) : ((7 + p_mem[7]) & 7);

                    // Check for collisions
                    collision = 0;
                    collision = collision | (dest0 == dest1);
                    collision = collision | (dest0 == dest2);
                    collision = collision | (dest0 == dest3);
                    collision = collision | (dest0 == dest4);
                    collision = collision | (dest0 == dest5);
                    collision = collision | (dest0 == dest6);
                    collision = collision | (dest0 == dest7);
                    collision = collision | (dest1 == dest2);
                    collision = collision | (dest1 == dest3);
                    collision = collision | (dest1 == dest4);
                    collision = collision | (dest1 == dest5);
                    collision = collision | (dest1 == dest6);
                    collision = collision | (dest1 == dest7);
                    collision = collision | (dest2 == dest3);
                    collision = collision | (dest2 == dest4);
                    collision = collision | (dest2 == dest5);
                    collision = collision | (dest2 == dest6);
                    collision = collision | (dest2 == dest7);
                    collision = collision | (dest3 == dest4);
                    collision = collision | (dest3 == dest5);
                    collision = collision | (dest3 == dest6);
                    collision = collision | (dest3 == dest7);
                    collision = collision | (dest4 == dest5);
                    collision = collision | (dest4 == dest6);
                    collision = collision | (dest4 == dest7);
                    collision = collision | (dest5 == dest6);
                    collision = collision | (dest5 == dest7);
                    collision = collision | (dest6 == dest7);

                    if (!collision) begin
                        solution <= mask_counter;
                        state_reg <= DONE;
                        valid <= 1;
                    end else begin
                        mask_counter <= mask_counter + 1;
                    end
                end else begin
                    state_reg <= DONE;
                    valid <= 0;
                end
            end
            DONE: // No action needed
            default: state_reg <= IDLE;
        endcase
    end
end

// Write logic for p_mem
always @(posedge clk) begin
    if (!rst_n) begin
        p_mem <= 8'b0;
        written_flags <= 8'b0;
        write_count <= 0;
    end else if (write_en && (addr >= 0 && addr < NUM_WIZARDS)) begin
        p_mem[addr] <= p_in;
        if (!written_flags[addr]) begin
            written_flags[addr] <= 1;
            write_count <= write_count + 1;
        end
    end
end
endmodule