module horse_chase (
    input clk,
    input rst_n,
    input start,
    input [3:0] L,
    input [3:0] A,
    input [3:0] B,
    input [3:0] P,
    output reg [3:0] result,
    output reg done
);

    // FSM states
    typedef enum logic [1:0] {
        IDLE,
        CALCULATE,
        FINISHED
    } state_t;

    state_t state;

    // Internal registers for BFS
    reg [11:0] frontier [0:15]; // 16 possible time steps (0-15)
    reg [11:0] next_frontier [0:15];
    reg [3:0] current_time;
    reg [3:0] min_time;
    reg found;

    // Visited states (4096 bits)
    reg [4095:0] visited;

    // Initialize
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            current_time <= 0;
            min_time <= 0;
            found <= 0;
            for (int i = 0; i < 16; i++) begin
                frontier[i] <= 0;
                next_frontier[i] <= 0;
            end
            visited <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CALCULATE;
                        // Initialize frontier with start state
                        frontier[0] <= {A, B, P};
                        visited[{A, B, P}] <= 1'b1;
                        current_time <= 0;
                        min_time <= 0;
                        found <= 0;
                    end
                end
                CALCULATE: begin
                    if (found) begin
                        state <= FINISHED;
                        result <= min_time;
                        done <= 1;
                    end else if (current_time == 15) begin
                        state <= FINISHED;
                        result <= 16;
                        done <= 1;
                    end else begin
                        // Process current frontier
                        for (int i = 0; i < 16; i++) begin
                            next_frontier[i] <= 0;
                        end
                        for (int i = 0; i < 16; i++) begin
                            if (frontier[i] != 0) begin
                                // Extract positions
                                reg [3:0] cow1 = frontier[i][11:8];
                                reg [3:0] cow2 = frontier[i][7:4];
                                reg [3:0] horse = frontier[i][3:0];

                                // Check capture
                                if (horse == cow1 || horse == cow2) begin
                                    found <= 1;
                                    min_time <= current_time;
                                end

                                // Generate next states
                                for (int dc1 = -1; dc1 <= 1; dc1++) begin
                                    for (int dc2 = -1; dc2 <= 1; dc2++) begin
                                        for (int dh = -2; dh <= 2; dh++) begin
                                            reg [3:0] new_cow1 = cow1 + dc1;
                                            reg [3:0] new_cow2 = cow2 + dc2;
                                            reg [3:0] new_horse = horse + dh;

                                            // Boundary checks
                                            if (new_cow1 > L) new_cow1 = L;
                                            if (new_cow1 < 0) new_cow1 = 0;
                                            if (new_cow2 > L) new_cow2 = L;
                                            if (new_cow2 < 0) new_cow2 = 0;
                                            if (new_horse > L) new_horse = L;
                                            if (new_horse < 0) new_horse = 0;

                                            // Collision check (horse cannot move to occupied position)
                                            if (new_horse != new_cow1 && new_horse != new_cow2) begin
                                                reg [11:0] new_state = {new_cow1, new_cow2, new_horse};
                                                if (!visited[new_state]) begin
                                                    visited[new_state] <= 1'b1;
                                                    // Add to next frontier
                                                    for (int j = 0; j < 16; j++) begin
                                                        if (next_frontier[j] == 0) begin
                                                            next_frontier[j] <= new_state;
                                                            break;
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        // Move to next time step
                        current_time <= current_time + 1;
                        for (int i = 0; i < 16; i++) begin
                            frontier[i] <= next_frontier[i];
                        end
                    end
                end
                FINISHED: begin
                    // Stay in finished state
                end
            endcase
        end
    end

endmodule