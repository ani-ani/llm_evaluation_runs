module occ_count #(parameter N=8, parameter WIDTH=8, parameter MAX_DISTINCT=8) (
    input clk,
    input rst_n,
    input start,
    input [N-1:0][WIDTH-1:0] data_in_0, // First element of each pair
    input [N-1:0][WIDTH-1:0] data_in_1, // Second element of each pair
    output reg [MAX_DISTINCT-1:0][WIDTH*2-1:0] out_keys, // Unique sorted pairs
    output reg [MAX_DISTINCT-1:0][3:0] out_counts, // Counts (max 15 for 4 bits)
    output reg done,
    output reg valid
);

    // State machine states
    localparam IDLE = 3'b000;
    localparam NORMALIZE = 3'b001;
    localparam COUNT = 3'b010;
    localparam FINISH = 3'b011;
    localparam OUTPUT = 3'b100;

    reg [2:0] state, next_state;
    reg [3:0] idx, next_idx; // Index for processing input array
    reg [3:0] k_idx, next_k_idx; // Index for distinct keys array
    reg [3:0] scan_idx, next_scan_idx; // Index for scanning keys during count
    
    // Normalized pairs stored in a register array
    reg [WIDTH*2-1:0] norm_pair [0:N-1];
    
    // Key and count storage
    reg [WIDTH*2-1:0] key_reg [0:MAX_DISTINCT-1];
    reg [3:0] count_reg [0:MAX_DISTINCT-1];
    
    // Temporary storage for comparison
    reg found;
    reg [WIDTH*2-1:0] current_pair;

    // Combinational Logic
    always @(*) begin
        next_state = state;
        next_idx = idx;
        next_k_idx = k_idx;
        next_scan_idx = 0;
        found = 0;
        current_pair = norm_pair[idx];
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = NORMALIZE;
                    next_idx = 0;
                    next_k_idx = 0;
                end
            end
            
            NORMALIZE: begin
                if (idx < N - 1) begin
                    next_idx = idx + 1;
                end else begin
                    next_idx = 0;
                    next_state = COUNT;
                end
            end
            
            COUNT: begin
                if (idx < N) begin
                    // Look for existing key
                    for (int j = 0; j < MAX_DISTINCT; j = j + 1) begin
                        if (j < k_idx && key_reg[j] == current_pair) begin
                            found = 1;
                        end
                    end
                    
                    if (!found && (k_idx < MAX_DISTINCT)) begin
                        // Add new key
                        next_k_idx = k_idx + 1;
                    end
                    next_idx = idx + 1;
                end else begin
                    next_state = OUTPUT;
                end
            end
            
            OUTPUT: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential Logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 0;
            k_idx <= 0;
            done <= 0;
            valid <= 0;
            for (i = 0; i < MAX_DISTINCT; i = i + 1) begin
                count_reg[i] <= 0;
                key_reg[i] <= 0;
                out_keys[i] <= 0;
                out_counts[i] <= 0;
            end
            for (i = 0; i < N; i = i + 1) begin
                norm_pair[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    valid <= 0;
                    if (start) begin
                        // Reset counters for new operation
                        for (i = 0; i < MAX_DISTINCT; i = i + 1) begin
                            count_reg[i] <= 0;
                            key_reg[i] <= 0;
                        end
                    end
                end
                
                NORMALIZE: begin
                    // Normalize pairs (swap if needed) as they are stored
                    if (data_in_0[idx] < data_in_1[idx]) begin
                        norm_pair[idx] <= {data_in_0[idx], data_in_1[idx]};
                    end else begin
                        norm_pair[idx] <= {data_in_1[idx], data_in_0[idx]};
                    end
                end
                
                COUNT: begin
                    // Process current pair
                    if (idx < N) begin
                        current_pair = norm_pair[idx];
                        found = 0;
                        
                        // Check if key already exists
                        for (int j = 0; j < MAX_DISTINCT; j = j + 1) begin
                            if (j < k_idx && key_reg[j] == current_pair) begin
                                found = 1;
                                count_reg[j] <= count_reg[j] + 1;
                            end
                        end
                        
                        // If not found and space available, add new key
                        if (!found && (k_idx < MAX_DISTINCT)) begin
                            key_reg[k_idx] <= current_pair;
                            count_reg[k_idx] <= 1;
                        end
                    end
                end
                
                OUTPUT: begin
                    // Transfer results to output ports
                    for (i = 0; i < MAX_DISTINCT; i = i + 1) begin
                        out_keys[i] <= key_reg[i];
                        out_counts[i] <= count_reg[i];
                    end
                end
                
                FINISH: begin
                    done <= 1;
                    valid <= 1;
                end
            endcase
            
            // State and index updates
            state <= next_state;
            idx <= next_idx;
            k_idx <= next_k_idx;
        end
    end

endmodule