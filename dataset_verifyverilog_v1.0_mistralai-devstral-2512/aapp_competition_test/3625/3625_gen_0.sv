module jack_forest(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] species_count,
    input wire [9:0] B_in,
    input wire [5:0] Y_in,
    input wire [9:0] I_in,
    input wire [9:0] S_in,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Storage arrays for species data
    reg [9:0] B [0:15];
    reg [5:0] Y [0:15];
    reg [9:0] I [0:15];
    reg [9:0] S [0:15];
    
    // Loop counters
    reg [9:0] year_counter;
    reg [3:0] species_counter;
    
    // Computation variables
    reg [15:0] current_total;
    reg [15:0] max_total;
    reg [9:0] t;
    reg [15:0] population;
    
    // Cycle counter for safety
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd20000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            year_counter <= 10'd0;
            species_counter <= 4'd0;
            current_total <= 16'd0;
            max_total <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            
            // Initialize arrays
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                B[i] <= 10'd0;
                Y[i] <= 6'd0;
                I[i] <= 10'd0;
                S[i] <= 10'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        next_state <= LOAD;
                        species_counter <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                LOAD: begin
                    // Store current species data
                    B[species_counter] <= B_in;
                    Y[species_counter] <= Y_in;
                    I[species_counter] <= I_in;
                    S[species_counter] <= S_in;
                    
                    // Move to next species or start computation
                    if (species_counter == species_count - 1) begin
                        next_state <= COMPUTE;
                        year_counter <= 10'd0;
                        max_total <= 16'd0;
                    end else begin
                        species_counter <= species_counter + 1'b1;
                        next_state <= LOAD;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Calculate population for current species
                    if (species_counter == 0) begin
                        current_total <= 16'd0;
                    end
                    
                    t <= year_counter - B[species_counter];
                    
                    if (year_counter >= B[species_counter]) begin
                        if (t <= Y[species_counter]) begin
                            // Growing phase
                            population <= S[species_counter] + t * I[species_counter];
                        end else begin
                            // Decay phase
                            population <= S[species_counter] + Y[species_counter] * I[species_counter] - (t - Y[species_counter]) * I[species_counter];
                        end
                        
                        // Ensure population doesn't go negative
                        if (population < 16'd0) begin
                            population <= 16'd0;
                        end
                        
                        current_total <= current_total + population;
                    end
                    
                    // Move to next species or next year
                    if (species_counter == species_count - 1) begin
                        // Compare with max
                        if (current_total > max_total) begin
                            max_total <= current_total;
                        end
                        
                        // Move to next year
                        if (year_counter == 10'd1023) begin
                            next_state <= FINISH;
                            result <= max_total;
                        end else begin
                            year_counter <= year_counter + 1'b1;
                            species_counter <= 4'd0;
                            next_state <= COMPUTE;
                        end
                    end else begin
                        species_counter <= species_counter + 1'b1;
                        next_state <= COMPUTE;
                    end
                    
                    // Safety check
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                        result <= max_total;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule