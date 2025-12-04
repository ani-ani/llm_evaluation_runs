module rectangle_extensions (
    input clk,
    input rst_n,
    input start,
    input [31:0] a, b, h, w,
    input [15:0][31:0] factors,
    input [4:0] num_factors,
    output reg [4:0] min_count,
    output reg done
);

    typedef enum {IDLE, SORT, PROCESS, CHECK, DONE} state_t;
    state_t state, next_state;

    reg [15:0][31:0] sorted_factors;
    reg [31:0] working_factors[0:15];
    reg [4:0] sort_index;
    reg [4:0] proc_index;
    reg [4:0] check_index;
    reg [4:0] extension_count;

    // Current pair storage
    typedef struct packed {
        logic valid;
        logic [31:0] h;
        logic [31:0] w;
    } pair_t;
    
    pair_t current_pairs [0:15];
    pair_t next_pairs [0:31];
    reg [5:0] pair_count;

    // Sorting signals
    reg sort_done;
    
    // Process signals
    wire condition_met;
    reg met_flag;

    // Combinational condition check
    function automatic logic check_condition(logic [31:0] h_val, logic [31:0] w_val);
        return ((h_val >= a && w_val >= b) || (h_val >= b && w_val >= a));
    endfunction

    // Sort factors in descending order
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            min_count <= 31;
        end
        else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    met_flag <= 0;
                    if (start) begin
                        // Initialize sorted factors
                        for (int i=0; i<16; i=i+1)
                            working_factors[i] <= (i < num_factors) ? factors[i] : 0;
                        state <= SORT;
                        sort_index <= 1;
                        sort_done <= 0;
                    end
                end

                SORT: begin
                    if (sort_index < num_factors) begin
                        automatic logic [31:0] key = working_factors[sort_index];
                        automatic integer j = sort_index - 1;
                        while (j >= 0 && working_factors[j] < key) begin
                            working_factors[j+1] <= working_factors[j];
                            j = j - 1;
                        end
                        working_factors[j+1] <= key;
                        sort_index <= sort_index + 1;
                    end else begin
                        // Transfer to sorted_factors
                        foreach (working_factors[i])
                            sorted_factors[i] <= working_factors[i];
                        state <= PROCESS;
                        // Initialize pairs
                        foreach (current_pairs[i]) current_pairs[i].valid <= 0;
                        current_pairs[0] <= '{valid:1, h:h, w:w};
                        current_pairs[1] <= '{valid:1, h:w, w:h};
                        pair_count <= 2;
                        proc_index <= 0;
                        extension_count <= 0;
                    end
                end

                PROCESS: begin
                    state <= CHECK;
                    met_flag <= 0;
                    // Generate next_pairs
                    foreach (next_pairs[i]) next_pairs[i].valid <= 0;
                    automatic int idx = 0;
                    automatic logic [31:0] factor = sorted_factors[proc_index];
                    
                    for (int i=0; i<16; i++) begin
                        if (current_pairs[i].valid) begin
                            // Apply to h
                            next_pairs[idx] <= '{valid:1, h:(current_pairs[i].h * factor), w:current_pairs[i].w};
                            idx++;
                            // Apply to w
                            next_pairs[idx] <= '{valid:1, h:current_pairs[i].h, w:(current_pairs[i].w * factor)};
                            idx++;
                        end
                    end
                    extension_count <= extension_count + 1;
                    proc_index <= proc_index + 1;
                end

                CHECK: begin
                    // Check for met condition, remove dominated pairs
                    met_flag = 0;
                    foreach (next_pairs[i]) begin
                        if (next_pairs[i].valid && check_condition(next_pairs[i].h, next_pairs[i].w)) begin
                            met_flag <= 1;
                            break;
                        end
                    end

                    if (met_flag) begin
                        min_count <= extension_count;
                        done <= 1;
                        state <= DONE;
                    end
                    else if (proc_index == num_factors) begin
                        min_count <= 31;
                        done <= 1;
                        state <= DONE;
                    end
                    else begin
                        // Remove dominated pairs
                        automatic int cnt = 0;
                        for (int i=0; i<32; i++) begin
                            if (next_pairs[i].valid) begin
                                automatic logic dominated = 0;
                                for (int j=0; j<32; j++) begin
                                    if (i!=j && next_pairs[j].valid &&
                                        next_pairs[j].h >= next_pairs[i].h && 
                                        next_pairs[j].w >= next_pairs[i].w) begin
                                        dominated = 1;
                                        break;
                                    end
                                end
                                if (!dominated) begin
                                    current_pairs[cnt] <= next_pairs[i];
                                    cnt++;
                                end
                            end
                        end
                        pair_count <= cnt;
                        for (int i=cnt; i<16; i++)
                            current_pairs[i].valid <= 0;
                        state <= PROCESS;
                    end
                end

                DONE: begin
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule