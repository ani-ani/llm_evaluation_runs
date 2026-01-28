module max_students(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [8:0] h [0:15],
    input wire sex [0:15],
    input wire [2:0] music [0:15],
    input wire [2:0] sport [0:15],
    output reg [7:0] result,
    output reg done
);

    localparam [3:0] MAX_N = 16;
    localparam [8:0] CLK_DELAY = 200;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] BUILD_EDGES = 3'd1;
    localparam [2:0] MATCHING = 3'd2;
    localparam [2:0] CALCULATE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [8:0] clk_counter;

    // Internal registers for inputs
    reg [8:0] h_reg [0:15];
    reg sex_reg [0:15];
    reg [2:0] music_reg [0:15];
    reg [2:0] sport_reg [0:15];

    // Bipartite matching variables
    reg [3:0] matchL [0:15]; // -1 means unmatched
    reg [3:0] matchR [0:15]; // -1 means unmatched
    reg [15:0] adj_matrix [0:15]; // Adjacency matrix

    // Matching algorithm variables
    reg [3:0] u;
    reg [3:0] v;
    reg [3:0] w;
    reg [15:0] seen;
    reg [3:0] matching_count;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            clk_counter <= 9'd0;
            result <= 8'd0;
            done <= 1'b0;
            
            // Initialize input registers
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                h_reg[i] <= 9'd0;
                sex_reg[i] <= 1'b0;
                music_reg[i] <= 3'd0;
                sport_reg[i] <= 3'd0;
            end
            
            // Initialize matching variables
            for (i = 0; i < 16; i = i + 1) begin
                matchL[i] <= 4'd15; // Using 15 as -1
                matchR[i] <= 4'd15;
                adj_matrix[i] <= 16'd0;
            end
            
            u <= 4'd0;
            v <= 4'd0;
            w <= 4'd0;
            seen <= 16'd0;
            matching_count <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            next_state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        next_state <= BUILD_EDGES;
                        clk_counter <= 9'd0;
                        
                        // Store inputs
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            h_reg[i] <= h[i];
                            sex_reg[i] <= sex[i];
                            music_reg[i] <= music[i];
                            sport_reg[i] <= sport[i];
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end

                BUILD_EDGES: begin
                    if (clk_counter < 9'd255) begin
                        clk_counter <= clk_counter + 9'd1;
                        
                        // Build adjacency matrix
                        integer i, j;
                        for (i = 0; i < 16; i = i + 1) begin
                            for (j = 0; j < 16; j = j + 1) begin
                                if (sex_reg[i] != sex_reg[j]) begin
                                    // Check if they can be a couple
                                    reg [8:0] height_diff;
                                    if (h_reg[i] > h_reg[j]) begin
                                        height_diff <= h_reg[i] - h_reg[j];
                                    end else begin
                                        height_diff <= h_reg[j] - h_reg[i];
                                    end
                                    
                                    if (height_diff <= 9'd40 && 
                                        music_reg[i] == music_reg[j] &&
                                        sport_reg[i] != sport_reg[j]) begin
                                        // They can be a couple - add edge
                                        adj_matrix[i][j] <= 1'b1;
                                    end else begin
                                        adj_matrix[i][j] <= 1'b0;
                                    end
                                end else begin
                                    adj_matrix[i][j] <= 1'b0;
                                end
                            end
                        end
                        
                        next_state <= MATCHING;
                    end else begin
                        next_state <= MATCHING;
                    end
                end

                MATCHING: begin
                    if (clk_counter < 9'd400) begin
                        clk_counter <= clk_counter + 9'd1;
                        
                        // Bipartite matching algorithm
                        integer i, j;
                        
                        // Initialize matchL and matchR
                        for (i = 0; i < 16; i = i + 1) begin
                            matchL[i] <= 4'd15;
                            matchR[i] <= 4'd15;
                        end
                        
                        // Try to find matching for each male
                        for (u = 0; u < 16; u = u + 1) begin
                            if (sex_reg[u] == 1'b0) begin // Male
                                // Mark all females as not seen
                                seen <= 16'd0;
                                
                                // Try to find augmenting path
                                if (bpm(u)) begin
                                    matching_count <= matching_count + 4'd1;
                                end
                            end
                        end
                        
                        next_state <= CALCULATE;
                    end else begin
                        next_state <= CALCULATE;
                    end
                end

                CALCULATE: begin
                    // Calculate result
                    integer i;
                    reg [3:0] n;
                    n <= 4'd0;
                    
                    // Count actual number of students
                    for (i = 0; i < 16; i = i + 1) begin
                        if (h_reg[i] != 9'd0) begin
                            n <= n + 4'd1;
                        end
                    end
                    
                    result <= n - matching_count;
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

    // Bipartite matching function
    function bpm;
        input [3:0] u;
        integer v;
        
        for (v = 0; v < 16; v = v + 1) begin
            if (adj_matrix[u][v] && !seen[v]) begin
                seen[v] <= 1'b1;
                
                if (matchR[v] == 4'd15 || bpm(matchR[v])) begin
                    matchR[v] <= u;
                    matchL[u] <= v;
                    bpm = 1'b1;
                    return;
                end
            end
        end
        
        bpm = 1'b0;
    endfunction

endmodule