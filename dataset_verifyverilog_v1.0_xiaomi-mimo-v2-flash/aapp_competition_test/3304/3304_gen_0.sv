module SeatingProblem (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [3:0] A [0:15],
    input wire [15:0] P [0:15],
    input wire [15:0] V [0:15],
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SEATING = 2'd1;
    localparam [1:0] COUNTING = 2'd2;
    localparam [1:0] FINISHED = 2'd3;

    // Registers
    reg [1:0] state, next_state;
    reg [3:0] elf_idx;           // Current elf being seated (0 to N-1)
    reg [3:0] search_start;      // Starting position for search
    reg [3:0] search_pos;        // Current search position
    reg [3:0] dwarf_idx;         // Current dwarf for counting
    reg [15:0] count_reg;        // Accumulated victory count
    reg [3:0] owner [0:15];      // Which elf owns each dwarf (15 means no owner)
    reg [3:0] cycle_counter;     // Safety counter to prevent infinite loops
    localparam [3:0] MAX_CYCLES = 4'd16;

    integer i;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            elf_idx <= 4'd0;
            search_start <= 4'd0;
            search_pos <= 4'd0;
            dwarf_idx <= 4'd0;
            result <= 16'd0;
            done <= 1'b0;
            count_reg <= 16'd0;
            cycle_counter <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                owner[i] <= 4'd15;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 16'd0;
                    count_reg <= 16'd0;
                    elf_idx <= 4'd0;
                    cycle_counter <= 4'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        owner[i] <= 4'd15;
                    end
                    if (start) begin
                        // Calculate starting position for elf 0: (A[0] - 1) % N
                        if (A[0] == 4'd0) begin
                            search_start <= N - 4'd1;
                        end else begin
                            search_start <= A[0] - 4'd1;
                        end
                        search_pos <= A[0] - 4'd1;
                    end
                end

                SEATING: begin
                    cycle_counter <= cycle_counter + 4'd1;
                    // Search for empty slot
                    if (owner[search_pos] == 4'd15) begin
                        // Found empty slot
                        owner[search_pos] <= elf_idx;
                        // Next elf or done
                        if (elf_idx == N - 4'd1) begin
                            // All elves seated, start counting
                            elf_idx <= 4'd0;
                            dwarf_idx <= 4'd0;
                            cycle_counter <= 4'd0;
                        end else begin
                            // Next elf
                            elf_idx <= elf_idx + 4'd1;
                            // Calculate next elf's starting position
                            if (A[elf_idx + 4'd1] == 4'd0) begin
                                search_start <= N - 4'd1;
                            end else begin
                                search_start <= A[elf_idx + 4'd1] - 4'd1;
                            end
                            search_pos <= A[elf_idx + 4'd1] - 4'd1;
                            cycle_counter <= 4'd0;
                        end
                    end else begin
                        // Move clockwise
                        search_pos <= (search_pos + 4'd1) % N;
                    end
                end

                COUNTING: begin
                    // Check victory for current dwarf
                    if (owner[dwarf_idx] != 4'd15) begin
                        // Dwarf is owned by elf 'owner[dwarf_idx]'
                        if (V[owner[dwarf_idx]] > P[dwarf_idx]) begin
                            count_reg <= count_reg + 16'd1;
                        end
                    end
                    // Next dwarf or done
                    if (dwarf_idx == N - 4'd1) begin
                        result <= count_reg;
                        done <= 1'b1;
                    end else begin
                        dwarf_idx <= dwarf_idx + 4'd1;
                    end
                end

                FINISHED: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    if (N == 4'd1) begin
                        next_state = COUNTING; // No elves to seat
                    end else begin
                        next_state = SEATING;
                    end
                end else begin
                    next_state = IDLE;
                end
            end

            SEATING: begin
                // Check if we're done with all elves and found a slot
                if (owner[search_pos] == 4'd15 && elf_idx == N - 4'd1) begin
                    next_state = COUNTING;
                end else if (cycle_counter >= MAX_CYCLES) begin
                    next_state = FINISHED; // Fallback for safety
                end else begin
                    next_state = SEATING;
                end
            end

            COUNTING: begin
                if (dwarf_idx == N - 4'd1) begin
                    next_state = FINISHED;
                end else begin
                    next_state = COUNTING;
                end
            end

            FINISHED: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule