module turtle_dry_finder (
    input clk,
    input rst_n,
    input start,
    input [15:0] target_pattern,
    input [127:0] commands_packed,
    output reg [5:0] min_time,
    output reg [5:0] max_time,
    output reg valid,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam FETCH = 3'b001;
    localparam CALCULATE = 3'b010;
    localparam CHECK = 3'b011;
    localparam NEXT = 3'b100;
    localparam FINISHED = 3'b101;

    // Direction Encoding
    localparam DIR_UP = 2'b00;
    localparam DIR_RIGHT = 2'b01;
    localparam DIR_DOWN = 2'b10;
    localparam DIR_LEFT = 2'b11;

    // Registers
    reg [2:0] state;
    reg [4:0] cmd_index;       // 0 to 31
    reg [3:0] dist_remaining;  // 1 to 4 (Decoded from 0-3)
    reg [1:0] dist_code;       // Stored distance code
    reg [1:0] direction;       // Stored direction
    reg [1:0] cur_x;
    reg [1:0] cur_y;
    reg [15:0] current_marking;
    reg [5:0] current_step;
    reg min_latched;
    reg max_latched;

    // Wires for Command Extraction
    wire [3:0] current_cmd;
    assign current_cmd = commands_packed[cmd_index*4 +: 4];

    // Combinational Logic for Grid Index
    // Bit i corresponds to cell (i%4, i//4). 
    // We calculate index = y * 4 + x.
    wire [3:0] grid_index;
    assign grid_index = {cur_y, cur_x};

    // Next State Logic & Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_time <= 6'd32; // Initialize to max possible value (or higher)
            max_time <= 6'd0;
            valid <= 0;
            done <= 0;
            cmd_index <= 0;
            dist_remaining <= 0;
            cur_x <= 0;
            cur_y <= 0;
            current_marking <= 0;
            current_step <= 0;
            min_latched <= 0;
            max_latched <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= FETCH;
                        // Reset Counters/Registers
                        cmd_index <= 0;
                        cur_x <= 0;
                        cur_y <= 0;
                        current_marking <= 0;
                        current_step <= 0;
                        valid <= 0;
                        done <= 0;
                        // Min init to max possible steps + 1 (33), clamped to 63
                        min_time <= 6'd33;
                        max_time <= 6'd0;
                        min_latched <= 0;
                        max_latched <= 0;
                    end else begin
                        state <= IDLE;
                    end
                end

                FETCH: begin
                    // If we have processed all commands
                    if (cmd_index >= 32) begin
                        state <= FINISHED;
                    end else begin
                        // Extract command
                        // cmd[3:2] is distance code (0=1, 1=2, 2=3, 3=4)
                        // cmd[1:0] is direction
                        dist_code <= current_cmd[3:2];
                        direction <= current_cmd[1:0];
                        // Convert code to actual steps (Code 0 -> 1 step, Code 3 -> 4 steps)
                        dist_remaining <= current_cmd[3:2] + 1'b1;
                        state <= CALCULATE;
                    end
                end

                CALCULATE: begin
                    // Perform one step of movement
                    case (direction)
                        DIR_UP:    cur_y <= cur_y + 1'b1;
                        DIR_RIGHT: cur_x <= cur_x + 1'b1;
                        DIR_DOWN:  cur_y <= cur_y - 1'b1;
                        DIR_LEFT:  cur_x <= cur_x - 1'b1;
                    endcase
                    // Move to CHECK state to mark the new cell
                    state <= CHECK;
                end

                CHECK: begin
                    // Update marking for the cell we just moved to
                    current_marking[grid_index] <= 1'b1;
                    
                    // Check if current pattern matches target
                    // Note: Check happens after marking the cell
                    if ((current_marking | (1'b1 << grid_index)) == target_pattern) begin
                        // It matches!
                        // Record time (current_step + 1 because we just moved)
                        if (!min_latched) begin
                            min_time <= current_step + 1'b1;
                            min_latched <= 1;
                        end
                        // Always update max if we found a match
                        max_time <= current_step + 1'b1;
                        max_latched <= 1; // Indicates we found at least one match
                        valid <= 1;
                    end
                    state <= NEXT;
                end

                NEXT: begin
                    // Increment step counter (we just completed a move)
                    current_step <= current_step + 1'b1;

                    // Check if we need to move again for this command
                    if (dist_remaining > 1) begin
                        dist_remaining <= dist_remaining - 1'b1;
                        state <= CALCULATE; // Loop back for next step
                    end else begin
                        // Command finished, move to next command
                        cmd_index <= cmd_index + 1'b1;
                        state <= FETCH;
                    end
                end

                FINISHED: begin
                    // Latch results and signal done
                    // If no matches found, valid remains 0, min/max are undefined (we keep previous values)
                    // But problem implies valid=1 if times exist.
                    if (!max_latched) valid <= 0;
                    done <= 1;
                    if (!start) state <= IDLE; // Wait for reset or new start
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
