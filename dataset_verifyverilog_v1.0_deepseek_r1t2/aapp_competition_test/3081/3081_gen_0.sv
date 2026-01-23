module airline_fleet_minimization (    
    input wire clk,                             
    input wire rst_n,                          
    input wire start,                          
    input wire [31:0] data_in,                 
    input wire data_valid,                     
    input wire [1:0] data_type,                
    output reg [7:0] result,                   
    output reg done,                           
    output reg error                           
);                                             
                                               
    // State declarations                      
    localparam [2:0] IDLE        = 3'd0;       
    localparam [2:0] LOAD        = 3'd1;       
    localparam [2:0] SORT        = 3'd2;       
    localparam [2:0] BUILD_EDGES = 3'd3;       
    localparam [2:0] MATCHING    = 3'd4;       
    localparam [2:0] DONE_STATE  = 3'd5;       
                                               
    // Data storage                            
    reg [31:0] inspections [0:3];              
    reg [31:0] flight_times [0:15];            
    reg [1:0]  flights_s [0:3];                
    reg [1:0]  flights_f [0:3];                
    reg [31:0] flights_t [0:3];                
                                               
    // Sorting support                         
    reg [31:0] sort_t [0:3];                   
    reg [1:0]  sort_s [0:3];                   
    reg [1:0]  sort_f [0:3];                   
    reg [2:0]  sort_counter_i;                 
    reg [2:0]  sort_counter_j;                 
                                               
    // Edge matrix                             
    reg        edges [0:3][0:3];               
    reg [1:0]  edge_i;                         
    reg [1:0]  edge_j;                         
                                               
    // Matching registers                      
    reg [3:0]  matching;                       
    reg [3:0]  taken;                          
    reg [7:0]  max_match;                      
    reg [1:0]  curr_flight;                    
    reg [15:0] match_cycles;                   
    localparam [15:0] MAX_CYCLES = 16'd625;    
                                               
    // General FSM                             
    reg [2:0]  state, next_state;              
    reg [4:0]  data_counter;                   
    reg [7:0]  total_cycles;                   
                                               
    // State transitions                       
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin                      
            state <= IDLE;                     
            result <= 8'd0;                    
            done <= 1'b0;                      
            error <= 1'b0;                     
            data_counter <= 5'd0;              
            total_cycles <= 8'd0;              
            sort_counter_i <= 3'd0;            
            sort_counter_j <= 3'd0;            
            edge_i <= 2'd0;                    
            edge_j <= 2'd0;                    
            curr_flight <= 2'd0;               
            matching <= 4'd0;                  
            max_match <= 8'd0;                 
            taken <= 4'd0;                     
            match_cycles <= 16'd0;             
            // Initialize arrays               
            for (integer idx = 0; idx < 4; idx = idx + 1) begin
                inspections[idx] <= 32'd0;     
                flights_s[idx] <= 2'd0;        
                flights_f[idx] <= 2'd0;        
                flights_t[idx] <= 32'd0;       
                sort_s[idx] <= 2'd0;           
                sort_f[idx] <= 2'd0;           
                sort_t[idx] <= 32'd0;          
            end                                
            for (integer i = 0; i < 16; i = i + 1) flight_times[i] <= 32'd0;
            for (integer i = 0; i < 4; i = i + 1) for (integer j = 0; j < 4; j = j + 1) edges[i][j] <= 1'b0;
        end else begin                         
            state <= next_state;               
            total_cycles <= total_cycles + 8'd1;
            
            case (state)                       
                IDLE: begin                    
                    done <= 1'b0;              
                    error <= 1'b0;             
                    data_counter <= 5'd0;      
                    if (start) begin           
                        next_state <= LOAD;    
                        total_cycles <= 8'd0;  
                    end else begin             
                        next_state <= IDLE;    
                    end                        
                end                            
                LOAD: begin                    
                    if (data_valid) begin      
                        if (data_type == 2'b00) begin // Inspection
                            if (data_counter < 5'd4) begin
                                inspections[data_counter] <= data_in;
                                data_counter <= data_counter + 5'd1;
                            end else begin      
                                error <= 1'b1;  
                                next_state <= DONE_STATE;
                            end                 
                        end else if (data_type == 2'b01) begin // Flight time
                            if (data_counter >= 5'd4 && data_counter < 5'd20) begin
                                flight_times[data_counter - 5'd4] <= data_in;
                                data_counter <= data_counter + 5'd1;
                            end else begin     
                                error <= 1'b1;  
                                next_state <= DONE_STATE;
                            end                 
                        end else if (data_type == 2'b10) begin // Flight data
                            if (data_counter >= 5'd20 && (data_counter - 5'd20) % 3 == 0) begin
                                flights_s[(data_counter - 5'd20)/3] <= data_in[1:0];
                                data_counter <= data_counter + 5'd1;
                            end else if ((data_counter - 5'd20) % 3 == 1) begin
                                flights_f[(data_counter - 5'd20)/3] <= data_in[1:0];
                                data_counter <= data_counter + 5'd1;
                            end else if (data_counter >= 5'd20) begin
                                flights_t[(data_counter - 5'd20)/3] <= data_in;
                                data_counter <= data_counter + 5'd1;
                                if (data_counter == 5'd31) begin
                                    next_state <= SORT;
                                    for (integer k = 0; k < 4; k = k + 1) begin
                                        sort_s[k] <= flights_s[k];
                                        sort_f[k] <= flights_f[k];
                                        sort_t[k] <= flights_t[k];
                                    end        
                                end             
                            end else begin     
                                error <= 1'b1;  
                                next_state <= DONE_STATE;
                            end                 
                        end else begin         
                            error <= 1'b1;      
                            next_state <= DONE_STATE;
                        end                     
                    end                         
                    if (data_counter >= 5'd32) next_state <= SORT;
                end                            
                SORT: begin                    
                    if (sort_counter_i < 3'd3) begin // Bubble sort
                        if (sort_counter_j < 3'd3 - sort_counter_i) begin
                            if (sort_t[sort_counter_j] > sort_t[sort_counter_j + 1]) begin
                                // Swap entries
                                begin          
                                    reg [31:0] temp_t;
                                    reg [1:0]  temp_s, temp_f;
                                    temp_t = sort_t[sort_counter_j];
                                    temp_s = sort_s[sort_counter_j];
                                    temp_f = sort_f[sort_counter_j];
                                    sort_t[sort_counter_j] <= sort_t[sort_counter_j + 1];
                                    sort_s[sort_counter_j] <= sort_s[sort_counter_j + 1];
                                    sort_f[sort_counter_j] <= sort_f[sort_counter_j + 1];
                                    sort_t[sort_counter_j + 1] <= temp_t;
                                    sort_s[sort_counter_j + 1] <= temp_s;
                                    sort_f[sort_counter_j + 1] <= temp_f;
                                end             
                            end                 
                            sort_counter_j <= sort_counter_j + 3'd1;
                        end else begin         
                            sort_counter_j <= 3'd0;
                            sort_counter_i <= sort_counter_i + 3'd1;
                        end                     
                    end else begin             
                        next_state <= BUILD_EDGES;
                        edge_i <= 2'd0;        
                        edge_j <= 2'd0;        
                        sort_counter_i <= 3'd0;
                        sort_counter_j <= 3'd0;
                    end                         
                end                            
                BUILD_EDGES: begin             
                    if (edge_i < 2'd4) begin   
                        if (edge_j < 2'd4) begin
                            if (edge_i != edge_j) begin
                                reg [31:0] time_needed_arrival;
                                reg [31:0] time_needed_depart;
                                reg [3:0] arrival_airport, dep_airport;
                                arrival_airport = sort_f[edge_i];
                                dep_airport = sort_s[edge_j];
                                time_needed_arrival = sort_t[edge_i] + flight_times[sort_f[edge_i]*4 + sort_s[edge_i]];
                                time_needed_arrival = time_needed_arrival + inspections[sort_s[edge_i]];
                                time_needed_depart = sort_t[edge_j];
                                edges[edge_i][edge_j] <= (time_needed_arrival <= time_needed_depart);
                            end else begin     
                                edges[edge_i][edge_j] <= 1'b0;
                            end                 
                            edge_j <= edge_j + 2'd1;
                        end else begin         
                            edge_j <= 2'd0;    
                            edge_i <= edge_i + 2'd1;
                        end                     
                    end else begin             
                        next_state <= MATCHING;
                        curr_flight <= 2'd0;   
                        matching <= 4'd0;      
                        taken <= 4'd0;         
                        max_match <= 8'd0;     
                        match_cycles <= 16'd0; 
                    end                         
                end                            
                MATCHING: begin                
                    match_cycles <= match_cycles + 16'd1;
                    if (curr_flight < 2'd4) begin
                        integer k;             
                        for (k = 0; k < 4; k = k + 1) begin
                            if (!taken[k] && edges[curr_flight][k]) begin
                                taken[k] <= 1'b1;
                                matching[curr_flight] <= k;
                                curr_flight <= curr_flight + 2'd1;
                                if (matching + 8'd1 > max_match) begin
                                    max_match <= matching + 8'd1;
                                end             
                                k = 4; // Break
                            end else begin     
                                matching[curr_flight] <= 4'b1111; // Not matched
                                curr_flight <= curr_flight + 2'd1;
                            end                 
                        end                     
                    end else begin             
                        curr_flight <= 2'd0;   
                        matching <= 4'd0;      
                        taken <= 4'd0;         
                        // Check if tried all combinations
                        if (match_cycles >= MAX_CYCLES) begin
                            next_state <= DONE_STATE;
                        end                     
                    end                         
                end                            
                DONE_STATE: begin             
                    done <= 1'b1;              
                    result <= 8'd4 - max_match; // min_planes = flights - max_matching
                    next_state <= IDLE;         
                end                            
                default: begin                 
                    next_state <= IDLE;         
                end                            
            endcase                           
        end                                    
    end                                        
endmodule                                      
