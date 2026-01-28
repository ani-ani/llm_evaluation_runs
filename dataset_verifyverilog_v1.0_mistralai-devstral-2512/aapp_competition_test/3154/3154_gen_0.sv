module toy_assignment(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] event_data,
    input wire event_valid,
    input wire event_done,
    output reg [15:0] result,
    output reg done,
    output reg ready
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INPUT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Event buffer (16 slots)
    reg [31:0] event_buffer [0:15];
    reg [3:0] event_count;
    reg [3:0] event_ptr;

    // History matrix: 16 kids x 16 toys
    reg [15:0] duration [0:15][0:15];
    reg [15:0] first_start [0:15][0:15];

    // Preference matrix: For each kid, ranking of toys
    reg [3:0] preference [0:15][0:15];

    // Envy matrix: For each toy, list of kids who played with it
    reg [15:0] envy_mask [0:15];

    // Matching result
    reg [3:0] assignment [0:15];
    reg [15:0] result_reg;

    // Control signals
    reg input_complete;
    reg compute_complete;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            event_count <= 4'd0;
            event_ptr <= 4'd0;
            input_complete <= 1'b0;
            compute_complete <= 1'b0;
            done <= 1'b0;
            ready <= 1'b1;
            result <= 16'd0;
            result_reg <= 16'd0;

            // Initialize event buffer
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                event_buffer[i] <= 32'd0;
            end

            // Initialize history matrix
            integer j;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    duration[i][j] <= 16'd0;
                    first_start[i][j] <= 16'd0;
                end
            end

            // Initialize preference matrix
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    preference[i][j] <= 4'd0;
                end
            end

            // Initialize envy matrix
            for (i = 0; i < 16; i = i + 1) begin
                envy_mask[i] <= 16'd0;
            end

            // Initialize assignment
            for (i = 0; i < 16; i = i + 1) begin
                assignment[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    ready <= 1'b1;
                    input_complete <= 1'b0;
                    compute_complete <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        state <= INPUT;
                        ready <= 1'b0;
                    end
                end

                INPUT: begin
                    ready <= 1'b1;
                    
                    if (event_valid && event_count < 4'd16) begin
                        event_buffer[event_count] <= event_data;
                        event_count <= event_count + 4'd1;
                        ready <= 1'b0;
                    end
                    
                    if (event_done) begin
                        input_complete <= 1'b1;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    ready <= 1'b0;
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (!input_complete) begin
                        // Process events
                        integer i;
                        for (i = 0; i < event_count; i = i + 1) begin
                            reg [3:0] k = event_buffer[i][19:16];
                            reg [3:0] t = event_buffer[i][15:12];
                            reg [15:0] s = event_buffer[i][15:0];
                            
                            if (duration[k][t] == 16'd0) begin
                                first_start[k][t] <= s;
                            end
                            duration[k][t] <= duration[k][t] + 16'd1;
                            envy_mask[t][k] <= 1'b1;
                        end
                        input_complete <= 1'b1;
                    end else if (!compute_complete) begin
                        // Build preference matrix
                        integer i, j, rank;
                        for (i = 0; i < 16; i = i + 1) begin
                            for (rank = 0; rank < 16; rank = rank + 1) begin
                                reg [15:0] min_start = 16'd65535;
                                reg [3:0] best_toy = 4'd0;
                                
                                for (j = 0; j < 16; j = j + 1) begin
                                    if (first_start[i][j] < min_start && first_start[i][j] != 16'd0) begin
                                        integer k;
                                        reg found = 1'b0;
                                        for (k = 0; k < rank; k = k + 1) begin
                                            if (preference[i][k] == j) begin
                                                found = 1'b1;
                                            end
                                        end
                                        
                                        if (!found) begin
                                            min_start = first_start[i][j];
                                            best_toy = j;
                                        end
                                    end
                                end
                                
                                if (min_start != 16'd65535) begin
                                    preference[i][rank] <= best_toy;
                                end else begin
                                    preference[i][rank] <= 4'd0;
                                end
                            end
                        end

                        // Compute envy conditions
                        integer t;
                        for (t = 0; t < 16; t = t + 1) begin
                            reg [15:0] max_duration = 16'd0;
                            integer k;
                            for (k = 0; k < 16; k = k + 1) begin
                                if (duration[k][t] > max_duration) begin
                                    max_duration = duration[k][t];
                                end
                            end
                            
                            for (k = 0; k < 16; k = k + 1) begin
                                if (duration[k][t] < max_duration) begin
                                    envy_mask[t][k] <= 1'b1;
                                end else begin
                                    envy_mask[t][k] <= 1'b0;
                                end
                            end
                        end

                        // Bipartite matching
                        integer k, t, u;
                        reg [3:0] toy_assigned [0:15];
                        
                        for (k = 0; k < 16; k = k + 1) begin
                            toy_assigned[k] <= 4'd0;
                        end
                        
                        for (k = 0; k < 16; k = k + 1) begin
                            reg [3:0] best_toy = 4'd0;
                            reg [15:0] best_pref = 16'd65535;
                            
                            for (t = 0; t < 16; t = t + 1) begin
                                reg valid = 1'b1;
                                
                                // Check if assignment is valid
                                for (u = 0; u < 16; u = u + 1) begin
                                    if (u != k && toy_assigned[u] != 4'd0) begin
                                        reg [3:0] other_toy = toy_assigned[u];
                                        
                                        // Check if k envies u for other_toy
                                        if (envy_mask[other_toy][k] && 
                                            preference[k][t] > preference[k][other_toy]) begin
                                            valid = 1'b0;
                                        end
                                    end
                                end
                                
                                if (valid && preference[k][t] < best_pref) begin
                                    best_pref = preference[k][t];
                                    best_toy = t;
                                end
                            end
                            
                            if (best_toy != 4'd0) begin
                                assignment[k] <= best_toy;
                                toy_assigned[best_toy] <= k;
                            end else begin
                                assignment[k] <= 4'd0;
                            end
                        end

                        // Pack result
                        reg impossible = 1'b0;
                        for (k = 0; k < 16; k = k + 1) begin
                            if (assignment[k] == 4'd0) begin
                                impossible = 1'b1;
                            end
                        end
                        
                        if (impossible) begin
                            result_reg <= 16'd65535;
                        end else begin
                            for (k = 0; k < 16; k = k + 1) begin
                                result_reg[k*2 +: 2] <= assignment[k];
                            end
                        end
                        
                        compute_complete <= 1'b1;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    result <= result_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule