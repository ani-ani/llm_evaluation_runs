module circle_dance_solver (
    input clk,
    input rst_n,
    input start_load,
    input [2:0] addr,
    input [2:0] p_in,
    input write_en,
    output reg [7:0] solution_mask,
    output reg valid,
    output reg done
);

    // Internal memory for p values
    reg [2:0] p_mem [0:7];
    
    // State definitions
    localparam IDLE = 2'b00;
    localparam LOAD = 2'b01;
    localparam CHECKING = 2'b10;
    localparam DONE = 2'b11;
    
    reg [1:0] state;
    reg [7:0] mask_iter; // Iterates 0 to 255
    reg [2:0] dests [0:7]; // Computed destinations
    reg collision;
    reg [7:0] best_mask;
    reg found;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            mask_iter <= 0;
            solution_mask <= 0;
            valid <= 0;
            done <= 0;
            found <= 0;
            best_mask <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start_load) begin
                        state <= LOAD;
                    end
                end
                LOAD: begin
                    if (write_en) begin
                        p_mem[addr] <= p_in;
                    end
                    if (!start_load) begin
                        state <= CHECKING;
                        mask_iter <= 0;
                        found <= 0;
                        best_mask <= 0;
                    end
                end
                CHECKING: begin
                    if (mask_iter == 255) begin
                        if (found) begin
                            solution_mask <= best_mask;
                            valid <= 1;
                            done <= 1;
                            state <= DONE;
                        end else begin
                            valid <= 0;
                            done <= 1;
                            state <= DONE;
                        end
                    end else begin
                        // Compute destinations for current mask
                        for (int i = 0; i < 8; i = i + 1) begin
                            if (mask_iter[i]) begin
                                dests[i] = (i + p_mem[i]) % 8;
                            end else begin
                                dests[i] = (i - p_mem[i] + 8) % 8;
                            end
                        end
                        
                        // Check for collisions
                        collision = 0;
                        for (int i = 0; i < 8; i = i + 1) begin
                            for (int j = i + 1; j < 8; j = j + 1) begin
                                if (dests[i] == dests[j]) begin
                                    collision = 1;
                                end
                            end
                        end
                        
                        if (!collision && !found) begin
                            best_mask = mask_iter;
                            found = 1;
                        end
                        
                        mask_iter <= mask_iter + 1;
                    end
                end
                DONE: begin
                    // Stay in DONE until reset
                end
            endcase
        end
    end

endmodule