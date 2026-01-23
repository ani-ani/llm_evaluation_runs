module merge_three_sorted_lists(
    input [7:0] list1_size,
    input [7:0] list2_size,
    input [7:0] list3_size,
    input [2:0][7:0] list1,
    input [2:0][7:0] list2,
    input [2:0][7:0] list3,
    output reg [5:0] result_size,
    output reg [23:0][7:0] result
);

    // Use localparam for max sizes and pointer width
    localparam MAX_ELEMS = 8;
    localparam MAX_RESULT = 24;
    localparam PTR_W = 3;

    // Infinity value (max value for 8 bits)
    localparam [7:0] INF = 8'hFF;

    // Helper logic to pad input lists with INF for easier comparison
    // This allows treating exhausted lists as providing INF
    wire [MAX_ELEMS-1:0][7:0] padded_list1;
    wire [MAX_ELEMS-1:0][7:0] padded_list2;
    wire [MAX_ELEMS-1:0][7:0] padded_list3;

    assign padded_list1 = {list1, {8{INF}}}; // Pad remaining 5 elements with INF
    assign padded_list2 = {list2, {8{INF}}};
    assign padded_list3 = {list3, {8{INF}}};

    // Pointers for each list (combinational, tracking current position)
    // We cannot easily use a loop for sequential pointers in purely combinational logic
    // without creating a massive state machine or pipelining.
    // However, we can use a generate block to create an iteration tree.

    // Given the requirement for "parallel comparison logic" and "track pointers implicitly",
    // a recursive or iterative merge network is the most efficient hardware approach.
    // We will generate the logic to merge the elements step-by-step.

    // To handle the dynamic size correctly (stopping when sizes are reached),
    // we need to know how many elements have been consumed. 
    // Since this is combinational, we essentially "simulate" the merge.
    // We will create a structure that iterates up to MAX_RESULT times.

    // Internal state signals for the merge tree
    // We declare signals for each stage of the merge.
    // Since generate loops in Verilog cannot easily handle variable loop bounds based on internal state changes
    // (like pointers moving) without hierarchy or complex recursion, we will flatten the logic.
    // We will generate a large MUX structure that selects the next element based on current pointers.

    // However, standard Verilog generate doesn't support feedback (pointers updating based on selected values).
    // A pure combinational block that mimics a loop requires a recursive module or an always_comb block.
    // Given the constraints, we will use a generate block to unroll the merge steps.

    // We need 24 stages of selection logic.
    // For each stage 'i', we need to know the pointers for lists 1, 2, 3.
    // But pointers depend on the previous selections.
    // This creates a dependency chain: Sel(i) -> Ptr(i) -> Sel(i+1).

    // We will use a single combinational always block with a loop variable to generate the logic.
    // This is synthesizable as it unrolls into a massive combinational chain.

    integer i;
    reg [PTR_W-1:0] p1, p2, p3;

    always @* begin
        // Initialize pointers and result
        // We need to track pointers for this iteration sequence.
        reg [2:0] ptr1, ptr2, ptr3;
        reg [5:0] size;
        reg [7:0] val1, val2, val3;
        reg [7:0] min_val;
        reg [1:0] sel; // 0: list1, 1: list2, 2: list3

        ptr1 = 0;
        ptr2 = 0;
        ptr3 = 0;
        size = 0;

        // Initialize result array to 'x or 0' - mostly to avoid latch inference if we don't write all entries
        // though with the size signal it's usually fine, but good practice.
        for (int j = 0; j < 24; j++) begin
            result[j] = 8'h00;
        end

        // Unrolled loop for max 24 elements
        for (i = 0; i < 24; i = i + 1) begin
            // Read current values (handle out of bounds by checking size)
            // We treat out of bounds as INF.
            val1 = (ptr1 < list1_size) ? list1[ptr1] : INF;
            val2 = (ptr2 < list2_size) ? list2[ptr2] : INF;
            val3 = (ptr3 < list3_size) ? list3[ptr3] : INF;

            // Determine minimum
            // Priority: If list1 is min, pick it. If list2 is min and <= others, pick it, etc.
            // Standard priority: A < B < C logic or just compare.
            // If val1 <= val2 and val1 <= val3 -> sel list1
            // Else if val2 <= val3 -> sel list2
            // Else sel list3

            if (val1 <= val2 && val1 <= val3) begin
                sel = 2'b00; // List 1
                min_val = val1;
            end else if (val2 <= val3) begin
                sel = 2'b01; // List 2
                min_val = val2;
            end else begin
                sel = 2'b10; // List 3
                min_val = val3;
            end

            // Store result if we haven't filled the buffer yet
            if (size < MAX_RESULT) begin
                result[size] = min_val;
                size = size + 1;

                // Advance pointer based on selection
                if (sel == 2'b00) ptr1 = ptr1 + 1;
                else if (sel == 2'b01) ptr2 = ptr2 + 1;
                else ptr3 = ptr3 + 1;
            end
            // If size is full, we stop updating pointers and result.
            // The loop continues but assignments are guarded by `if (size < MAX_RESULT)`.
            // However, `ptr1 = ptr1 + 1` is inside that block, so pointers don't advance when full.
        end

        result_size = size;
    end

endmodule
