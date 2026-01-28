module DwarfElfSeating(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [3:0] A [0:15],
    input [15:0] P [0:15],
    input [15:0] V [0:15],
    output reg [15:0] result,
    output reg done
);

    localparam [3:0] MAX_N = 4'd16;
    
    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] SEAT_ELVES = 3'd2;
    localparam [2:0] COUNT_VICTORIES = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    reg [2:0] state, next_state;
    reg [3:0] elf_idx;
    reg [3:0] search_idx;
    reg [3:0] dwarf_idx;
    reg [15:0] victory_count;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;
    
    // Occupied array (16 bits)
    reg [15:0] occupied;
    
    // Owner array (16x4 bits)
    reg [3:0] owner [0:15];
    
    // Initialize arrays
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            elf_idx <= 4'd0;
            search_idx <= 4'd0;
            dwarf_idx <= 4'd0;
            victory_count <= 16'd0;
            cycle_count <= 8'd0;
            result <= 16'd0;
            done <= 1'b0;
            
            // Initialize occupied and owner arrays
            for (i = 0; i < 16; i = i + 1) begin
                occupied[i] <= 1'b0;
                owner[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                INIT: begin
                    // Reset internal state
                    elf_idx <= 4'd0;
                    search_idx <= 4'd0;
                    dwarf_idx <= 4'd0;
                    victory_count <= 16'd0;
                    
                    // Clear arrays
                    for (i = 0; i < 16; i = i + 1) begin
                        occupied[i] <= 1'b0;
                        owner[i] <= 4'd0;
                    end
                    
                    next_state <= SEAT_ELVES;
                end
                
                SEAT_ELVES: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've seated all elves
                    if (elf_idx == N) begin
                        next_state <= COUNT_VICTORIES;
                    end else begin
                        // Calculate starting position (A[elf_idx] - 1) % N
                        if (cycle_count == 8'd0) begin
                            search_idx <= (A[elf_idx] - 4'd1) % N;
                        end
                        
                        // Search for empty slot
                        if (!occupied[search_idx]) begin
                            // Found empty slot
                            occupied[search_idx] <= 1'b1;
                            owner[search_idx] <= elf_idx;
                            elf_idx <= elf_idx + 4'd1;
                            cycle_count <= 8'd0;
                        end else begin
                            // Move to next slot
                            search_idx <= (search_idx + 4'd1) % N;
                        end
                        
                        // Safety: prevent infinite loops
                        if (cycle_count >= MAX_CYCLES) begin
                            next_state <= COUNT_VICTORIES;
                        end else begin
                            next_state <= SEAT_ELVES;
                        end
                    end
                end
                
                COUNT_VICTORIES: begin
                    // Check if we've counted all dwarves
                    if (dwarf_idx == N) begin
                        next_state <= FINISH;
                    end else begin
                        // Check if dwarf has an owner and V > P
                        if (occupied[dwarf_idx] && (V[owner[dwarf_idx]] > P[dwarf_idx])) begin
                            victory_count <= victory_count + 16'd1;
                        end
                        
                        dwarf_idx <= dwarf_idx + 4'd1;
                        next_state <= COUNT_VICTORIES;
                    end
                end
                
                FINISH: begin
                    result <= victory_count;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule