module virus_spread_sim(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [5:0] D,
    input wire [3:0] initial_infected_count,
    input wire [15:0] initial_infected_idx,
    input wire [31:0] s_arr [0:15],
    input wire [31:0] t_arr [0:15],
    output reg [15:0] result_mask,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INPUT = 3'd1;
    localparam [2:0] COMPUTE_GRAPH = 3'd2;
    localparam [2:0] SIMULATE = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;

    reg [2:0] state, next_state;

    // Internal registers
    reg [15:0] infected_mask;
    reg [15:0] new_infected;
    reg [3:0] day_counter;
    reg [3:0] i_counter;
    reg [3:0] j_counter;
    reg [15:0] contact_matrix [0:15];
    reg [31:0] s_ram [0:15];
    reg [31:0] t_ram [0:15];
    reg [3:0] node_count;
    reg [5:0] day_limit;

    // Cycle counter for timeout
    reg [12:0] cycle_count;
    localparam [12:0] MAX_CYCLES = 13'd2000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_mask <= 16'd0;
            done <= 1'b0;
            busy <= 1'b0;
            cycle_count <= 13'd0;
            day_counter <= 4'd0;
            i_counter <= 4'd0;
            j_counter <= 4'd0;
            infected_mask <= 16'd0;
            new_infected <= 16'd0;
            node_count <= 4'd0;
            day_limit <= 6'd0;
            
            // Initialize RAMs
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                s_ram[k] <= 32'd0;
                t_ram[k] <= 32'd0;
                contact_matrix[k] <= 16'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 13'd1;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= INPUT;
                        busy <= 1'b1;
                        cycle_count <= 13'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INPUT: begin
                    // Store inputs
                    node_count <= N;
                    day_limit <= D;
                    infected_mask <= initial_infected_idx;
                    
                    // Copy s_arr and t_arr to RAM
                    integer k;
                    for (k = 0; k < 16; k = k + 1) begin
                        s_ram[k] <= s_arr[k];
                        t_ram[k] <= t_arr[k];
                    end
                    
                    next_state <= COMPUTE_GRAPH;
                    i_counter <= 4'd0;
                    j_counter <= 4'd0;
                end

                COMPUTE_GRAPH: begin
                    // Compute contact matrix
                    if (i_counter < node_count) begin
                        if (j_counter < node_count) begin
                            // Check if intervals overlap
                            if (!(t_ram[i_counter] < s_ram[j_counter] || t_ram[j_counter] < s_ram[i_counter])) begin
                                contact_matrix[i_counter][j_counter] <= 1'b1;
                            end else begin
                                contact_matrix[i_counter][j_counter] <= 1'b0;
                            end
                            j_counter <= j_counter + 4'd1;
                        end else begin
                            j_counter <= 4'd0;
                            i_counter <= i_counter + 4'd1;
                        end
                    end else begin
                        next_state <= SIMULATE;
                        day_counter <= 4'd0;
                        i_counter <= 4'd0;
                        j_counter <= 4'd0;
                    end
                end

                SIMULATE: begin
                    if (day_counter < day_limit) begin
                        if (i_counter < node_count) begin
                            if (j_counter < node_count) begin
                                // Check if j is not infected and i is infected and they have contact
                                if (!infected_mask[j_counter] && infected_mask[i_counter] && contact_matrix[i_counter][j_counter]) begin
                                    new_infected[j_counter] <= 1'b1;
                                end
                                j_counter <= j_counter + 4'd1;
                            end else begin
                                j_counter <= 4'd0;
                                i_counter <= i_counter + 4'd1;
                            end
                        end else begin
                            // Update infected mask
                            infected_mask <= infected_mask | new_infected;
                            new_infected <= 16'd0;
                            
                            // Next day
                            day_counter <= day_counter + 4'd1;
                            i_counter <= 4'd0;
                            j_counter <= 4'd0;
                        end
                    end else begin
                        next_state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    result_mask <= infected_mask;
                    done <= 1'b1;
                    busy <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Timeout protection
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES && state != IDLE) begin
            state <= IDLE;
            busy <= 1'b0;
            done <= 1'b1;
            result_mask <= infected_mask;
        end
    end

endmodule