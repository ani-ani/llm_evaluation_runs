module strange_sort (
    input clk,
    input rst_n,
    input [7:0] data_in,
    input valid_in,
    input start,
    output reg [7:0] data_out,
    output reg valid_out,
    output reg done
);

    // Parameters
    parameter N = 8;
    parameter WIDTH = 8;

    // State encoding
    localparam IDLE = 3'b001;
    localparam LOADING = 3'b010;
    localparam SORTING = 3'b100;
    // OUTPUT state is handled within SORTING logic for streaming

    // Internal Registers
    reg [2:0] state, next_state;
    reg [WIDTH-1:0] buffer [0:N-1]; // Input buffer
    reg [N-1:0] valid_mask;          // Bitmask of valid (unsorted) elements
    reg [3:0] load_count;            // Counter for loaded elements
    reg [3:0] output_count;          // Counter for output elements
    reg is_min_cycle;                // 1 for min selection, 0 for max selection
    reg processing_done;             // Flag to indicate processing is complete
    reg [1:0] sort_pipeline_stage;   // To manage latency in SORTING state

    // Temp storage for comparison results
    reg [WIDTH-1:0] selected_val;
    reg [3:0] selected_idx;
    
    // Variables for loop/comparison logic
    integer i;
    reg signed [WIDTH-1:0] min_val;
    reg signed [WIDTH-1:0] max_val;
    reg [3:0] min_idx;
    reg [3:0] max_idx;
    reg signed [WIDTH-1:0] current_val;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOADING;
            end
            LOADING: begin
                // Transition to sorting if we have 8 elements or start is asserted again
                if (start) next_state = LOADING; // Reset behavior handled in datapath
                else if (load_count == N) next_state = SORTING;
            end
            SORTING: begin
                // Remain in SORTING until all outputs are generated
                if (processing_done) begin
                    if (start) next_state = LOADING; // Restart if start is pulsed
                    else next_state = IDLE;          // Else go to IDLE (or stay done)
                end else begin
                    next_state = SORTING;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
            load_count <= 0;
            output_count <= 0;
            valid_mask <= 0;
            is_min_cycle <= 1;
            processing_done <= 0;
            sort_pipeline_stage <= 0;
            valid_out <= 0;
            done <= 0;
            // Initialize buffer to X to avoid latches, though not strictly necessary for synthesis if written correctly
            for (i = 0; i < N; i = i + 1) buffer[i] <= 0;
        end else begin
            // Default assignments
            valid_out <= 0;
            done <= processing_done; // Latch done high until reset/start
            
            // State Transition Actions
            case (state)
                IDLE: begin
                    if (next_state == LOADING) begin
                        load_count <= 0;
                        valid_mask <= 0;
                        processing_done <= 0;
                        done <= 0;
                    end
                end

                LOADING: begin
                    if (start) begin
                        // Reset loading if start is pulsed
                        load_count <= 0;
                        valid_mask <= 0;
                    end else if (valid_in && load_count < N) begin
                        buffer[load_count] <= data_in;
                        valid_mask[load_count] <= 1'b1;
                        load_count <= load_count + 1;
                    end
                    // Check if we should transition to SORTING immediately if start pressed with partial data
                    if (next_state == SORTING) begin
                        load_count <= 0; // Reset for potential reuse
                        output_count <= 0;
                        is_min_cycle <= 1;
                        sort_pipeline_stage <= 0;
                    end
                end

                SORTING: begin
                    // Logic to handle streaming output with 1-cycle latency after finding value
                    // Pipeline Stage 0: Find Min/Max
                    // Pipeline Stage 1: Output Value and Update Mask
                    // Pipeline Stage 2: Done Check / State Update

                    if (sort_pipeline_stage == 2'b00) begin
                        // --- Combinational Search Logic (Simulated) ---
                        // Since this is a sequential block, we compute the search results here
                        // effectively simulating combinational logic driven by valid_mask
                        
                        min_val = 127; // Signed max for 8-bit is 127, but let's use wider logic to be safe
                        max_val = -128;
                        min_idx = 0;
                        max_idx = 0;
                        
                        // Iterate to find current min and max among valid elements
                        // Using a for loop inside a sequential block infers registers for the intermediate values
                        // but we need to update them based on the current clock cycle's inputs (valid_mask/buffer)
                        // To make this purely combinational within the clock edge, we use intermediate combinational variables defined outside
                        // However, standard Verilog requires explicit continuous assignments or always_comb for combinational logic.
                        // Here, we will do the calculation in a combinational block and use the result in the sequential block.
                        
                        // To adhere to the 'expert' requirement and avoid complex sub-modules, we embed logic.
                        // Let's use a combinational block for the comparison to ensure correct logic.
                        // (Defined below this block)
                    end
                    
                    // Handling the streaming pipeline
                    if (sort_pipeline_stage == 2'b01) begin
                        // Output the value found in previous cycle (if mask wasn't empty)
                        if (valid_mask != 0) begin
                            data_out <= selected_val;
                            valid_out <= 1'b1;
                            // Mark as used
                            valid_mask[selected_idx] <= 1'b0;
                            output_count <= output_count + 1;
                            is_min_cycle <= ~is_min_cycle;
                        end
                    end

                    if (sort_pipeline_stage == 2'b10) begin
                        // Check completion
                        if (valid_mask == 0) begin
                            processing_done <= 1'b1;
                            done <= 1'b1;
                            // Stay in this state until start or reset, handled by next_state logic
                        end
                    end

                    // Pipeline counter
                    if (valid_mask == 0) begin
                         // Keep pipeline halted if done, or advance if we need to output final nil signal (not needed)
                         // Actually, we need to output the last element. 
                         // The pipeline flows: Find -> Output -> Update. 
                         // Last element: Find -> Output -> Update(Mask=0) -> Check Done.
                         // So we continue cycling.
                         sort_pipeline_stage <= sort_pipeline_stage + 1; // keep cycling to process the last output 'done' signal
                    end else begin
                         sort_pipeline_stage <= sort_pipeline_stage + 1;
                    end
                end
            endcase
        end
    end

    // Combinational Logic for Min/Max Selection
    // This block updates 'selected_val' and 'selected_idx' based on 'valid_mask' and 'buffer'
    always @(*) begin
        reg signed [7:0] t_min_val;
        reg signed [7:0] t_max_val;
        reg [3:0] t_min_idx;
        reg [3:0] t_max_idx;
        
        t_min_val = 127;
        t_max_val = -128;
        t_min_idx = 0;
        t_max_idx = 0;
        
        for (i = 0; i < N; i = i + 1) begin
            if (valid_mask[i]) begin
                if (buffer[i] < t_min_val) begin
                    t_min_val = buffer[i];
                    t_min_idx = i;
                end
                if (buffer[i] > t_max_val) begin
                    t_max_val = buffer[i];
                    t_max_idx = i;
                end
            end
        end
        
        // Select based on current mode
        if (is_min_cycle) begin
            selected_val = t_min_val;
            selected_idx = t_min_idx;
        end else begin
            selected_val = t_max_val;
            selected_idx = t_max_idx;
        end
    end

    // Note on Latency:
    // Cycle 0 (State: SORTING, Stage 0): Computation of Min/Max
    // Cycle 1 (State: SORTING, Stage 1): Output 'valid_out' high, Update Mask
    // This implies 'valid_out' is delayed by 1 cycle relative to the computation start.
    // Since computation starts immediately upon entering SORTING (or after reset),
    // the first output is indeed delayed by the time taken to load.
    // Load takes 8 cycles (assuming 1 per cycle).
    // Then Stage 0, then Stage 1.
    // So total latency = 8 (Load) + 1 (Pipeline) = 9 cycles. Matches spec.

endmodule