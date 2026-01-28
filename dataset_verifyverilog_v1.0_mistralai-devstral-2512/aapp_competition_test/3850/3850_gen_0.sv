module KeyAssignment(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [4:0] k,
    input [15:0] p,
    input [15:0] people [0:7],
    input [15:0] keys [0:15],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Internal sorted arrays
    reg [15:0] sorted_people [0:7];
    reg [15:0] sorted_keys [0:15];
    
    // Sorting control
    reg [3:0] sort_i, sort_j;
    reg sort_done;
    
    // Computation control
    reg [4:0] window_start;
    reg [3:0] person_idx;
    reg [15:0] current_time;
    reg [15:0] max_time;
    reg [15:0] min_result;
    reg [15:0] abs_diff;
    
    // Cycle counter for timeout
    reg [8:0] cycle_count;
    localparam [8:0] MAX_CYCLES = 9'd500;

    // Bubble sort for people
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            cycle_count <= 9'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            sort_done <= 1'b0;
            window_start <= 5'd0;
            person_idx <= 4'd0;
            current_time <= 16'd0;
            max_time <= 16'd0;
            min_result <= 16'd0;
            
            // Initialize sorted arrays
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                sorted_people[i] <= people[i];
            end
            for (i = 0; i < 16; i = i + 1) begin
                sorted_keys[i] <= keys[i];
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 9'd0;
                    if (start) begin
                        state <= SORT;
                    end
                end
                
                SORT: begin
                    // Bubble sort for people
                    if (!sort_done) begin
                        if (sort_i < n - 1) begin
                            if (sort_j < n - sort_i - 1) begin
                                if (sorted_people[sort_j] > sorted_people[sort_j + 1]) begin
                                    reg [15:0] temp;
                                    temp = sorted_people[sort_j];
                                    sorted_people[sort_j] = sorted_people[sort_j + 1];
                                    sorted_people[sort_j + 1] = temp;
                                end
                                sort_j <= sort_j + 1;
                            end else begin
                                sort_j <= 4'd0;
                                sort_i <= sort_i + 1;
                            end
                        end else begin
                            sort_i <= 4'd0;
                            sort_j <= 4'd0;
                            sort_done <= 1'b1;
                        end
                    end else begin
                        // Bubble sort for keys
                        if (sort_i < k - 1) begin
                            if (sort_j < k - sort_i - 1) begin
                                if (sorted_keys[sort_j] > sorted_keys[sort_j + 1]) begin
                                    reg [15:0] temp;
                                    temp = sorted_keys[sort_j];
                                    sorted_keys[sort_j] = sorted_keys[sort_j + 1];
                                    sorted_keys[sort_j + 1] = temp;
                                end
                                sort_j <= sort_j + 1;
                            end else begin
                                sort_j <= 4'd0;
                                sort_i <= sort_i + 1;
                            end
                        end else begin
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 1;
                    
                    if (window_start == 5'd0) begin
                        min_result <= 16'd65535; // Initialize to max
                    end
                    
                    if (person_idx == 4'd0) begin
                        max_time <= 16'd0;
                    end
                    
                    if (person_idx < n) begin
                        // Calculate time for current person
                        if (sorted_people[person_idx] > sorted_keys[window_start + person_idx]) begin
                            abs_diff = sorted_people[person_idx] - sorted_keys[window_start + person_idx];
                        end else begin
                            abs_diff = sorted_keys[window_start + person_idx] - sorted_people[person_idx];
                        end
                        
                        current_time = abs_diff + 
                            ((sorted_keys[window_start + person_idx] > p) ? 
                                (sorted_keys[window_start + person_idx] - p) : 
                                (p - sorted_keys[window_start + person_idx]));
                        
                        if (current_time > max_time) begin
                            max_time = current_time;
                        end
                        
                        person_idx <= person_idx + 1;
                    end else begin
                        // Window complete, update min_result
                        if (max_time < min_result) begin
                            min_result = max_time;
                        end
                        
                        // Move to next window
                        window_start <= window_start + 1;
                        person_idx <= 4'd0;
                        
                        if (window_start + n > k) begin
                            state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    result <= min_result;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule