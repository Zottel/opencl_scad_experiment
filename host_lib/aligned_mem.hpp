#ifndef ALIGNED_MEM_HPP
#define ALIGNED_MEM_HPP

#include <stdlib.h>
//#include <cstdlib>
#include <new>

inline void* aligned_malloc(size_t size, size_t align) {
	void *result;
	if(posix_memalign(&result, align, size)) result = 0;
	return result;
}

inline void aligned_free(void *ptr) {
	free(ptr);
}

template <class T>
struct AlignedAllocator {
	typedef T value_type;
	size_t alignment = 64;
	AlignedAllocator() = default;
	
	template <class U> constexpr AlignedAllocator(const AlignedAllocator<U>&) noexcept {}
	
	T* allocate(std::size_t n) {
		if(n > std::size_t(-1) / sizeof(T)) throw std::bad_alloc();
		if(auto p = static_cast<T*>(aligned_malloc(n*sizeof(T), alignment))) return p;
		throw std::bad_alloc();
	}
	void deallocate(T* p, std::size_t) noexcept { aligned_free(p); }
};

template <class T, class U>
bool operator==(const AlignedAllocator<T>&, const AlignedAllocator<U>&) { return true; }
template <class T, class U>
bool operator!=(const AlignedAllocator<T>&, const AlignedAllocator<U>&) { return false; }

#endif /* ALIGNED_MEM_HPP */
